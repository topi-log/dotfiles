#!/usr/bin/env node
"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const dependencyRoot = path.join(os.homedir(), ".config", "creview", "node_modules");
const textmate = require(path.join(dependencyRoot, "vscode-textmate"));
const oniguruma = require(path.join(dependencyRoot, "vscode-oniguruma"));

const vscodeRoot = "/Applications/Visual Studio Code.app/Contents/Resources/app";

function extensionRoots() {
  const roots = [path.join(vscodeRoot, "extensions")];
  const userRoot = path.join(os.homedir(), ".vscode", "extensions");
  if (fs.existsSync(userRoot)) roots.push(userRoot);
  return roots;
}

function discover() {
  const languages = new Map();
  const grammars = new Map();
  for (const root of extensionRoots()) {
    if (!fs.existsSync(root)) continue;
    for (const name of fs.readdirSync(root)) {
      const directory = path.join(root, name);
      const manifestPath = path.join(directory, "package.json");
      if (!fs.existsSync(manifestPath)) continue;
      try {
        const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
        const contributes = manifest.contributes || {};
        for (const language of contributes.languages || []) {
          for (const extension of language.extensions || []) languages.set(extension.toLowerCase(), language.id);
          for (const filename of language.filenames || []) languages.set(filename.toLowerCase(), language.id);
        }
        for (const grammar of contributes.grammars || []) {
          if (grammar.scopeName && grammar.path) {
            grammars.set(grammar.scopeName, { language: grammar.language, file: path.resolve(directory, grammar.path) });
          }
        }
      } catch (_) {
        // One broken third-party manifest must not disable all highlighting.
      }
    }
  }
  return { languages, grammars };
}

function languageFor(file, languages) {
  const base = path.basename(file).toLowerCase();
  if (languages.has(base)) return languages.get(base);
  const matches = [...languages.keys()].filter(key => key.startsWith(".") && base.endsWith(key));
  matches.sort((a, b) => b.length - a.length);
  return matches.length ? languages.get(matches[0]) : undefined;
}

function loadTheme(file) {
  const value = JSON.parse(fs.readFileSync(file, "utf8"));
  let tokenColors = [];
  if (value.include) tokenColors = loadTheme(path.resolve(path.dirname(file), value.include));
  return tokenColors.concat(value.tokenColors || value.settings || []);
}

async function createRegistry(grammars) {
  const wasmPath = require.resolve(path.join(dependencyRoot, "vscode-oniguruma", "release", "onig.wasm"));
  await oniguruma.loadWASM(fs.readFileSync(wasmPath).buffer);
  const onigLib = Promise.resolve({
    createOnigScanner: sources => new oniguruma.OnigScanner(sources),
    createOnigString: source => new oniguruma.OnigString(source),
  });
  const registry = new textmate.Registry({
    onigLib,
    loadGrammar: async scopeName => {
      const entry = grammars.get(scopeName);
      if (!entry || !fs.existsSync(entry.file)) return null;
      return textmate.parseRawGrammar(fs.readFileSync(entry.file, "utf8"), entry.file);
    },
  });
  const themePath = path.join(vscodeRoot, "extensions", "theme-defaults", "themes", "dark_plus.json");
  registry.setTheme({
    name: "Dark+",
    settings: [{ settings: { foreground: "#D4D4D4", background: "#1E1E1E" } }, ...loadTheme(themePath)],
  });
  return registry;
}

function tokenize(content, grammar, colorMap) {
  if (!grammar) return content.split("\n").map(line => [[line, "#D4D4D4"]]);
  let stack = textmate.INITIAL;
  return content.split("\n").map(line => {
    const result = grammar.tokenizeLine2(line, stack);
    stack = result.ruleStack;
    const segments = [];
    for (let index = 0; index < result.tokens.length; index += 2) {
      const start = result.tokens[index];
      const metadata = result.tokens[index + 1];
      const end = index + 2 < result.tokens.length ? result.tokens[index + 2] : line.length;
      const foreground = (metadata >>> 15) & 0x1ff;
      segments.push([line.slice(start, end), colorMap[foreground] || "#D4D4D4"]);
    }
    return segments.length ? segments : [[line, "#D4D4D4"]];
  });
}

async function main() {
  const input = JSON.parse(fs.readFileSync(0, "utf8"));
  const discovered = discover();
  const language = languageFor(input.path, discovered.languages);
  const scope = [...discovered.grammars.entries()].find(([, value]) => value.language === language)?.[0];
  const registry = await createRegistry(discovered.grammars);
  const grammar = scope ? await registry.loadGrammar(scope) : null;
  const colorMap = registry.getColorMap();
  process.stdout.write(JSON.stringify({
    language: language || "plaintext",
    contents: input.contents.map(content => tokenize(content, grammar, colorMap)),
  }));
}

main().catch(error => {
  process.stderr.write(String(error.stack || error));
  process.exit(1);
});
