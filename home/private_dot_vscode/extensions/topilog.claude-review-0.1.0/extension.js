const vscode = require("vscode");
const fs = require("fs");
const path = require("path");
const cp = require("child_process");

const BEFORE_SCHEME = "claude-review-before";
const AFTER_SCHEME = "claude-review-after";

class ReviewState {
  constructor() {
    this.root = undefined;
    this.paneId = undefined;
    this.files = [];
    this.documents = new Map();
    this.comments = [];
    this.fileEmitter = new vscode.EventEmitter();
    this.commentEmitter = new vscode.EventEmitter();
  }

  git(args, options = {}) {
    return cp.execFileSync("git", ["-C", this.root, ...args], {
      encoding: options.encoding === null ? null : "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
  }

  setSession(root, paneId) {
    const actualRoot = cp.execFileSync("git", ["-C", root, "rev-parse", "--show-toplevel"], { encoding: "utf8" }).trim();
    this.comments.forEach(comment => comment.thread.dispose());
    this.root = actualRoot;
    this.paneId = paneId;
    this.comments = [];
    this.refresh();
  }

  refresh() {
    if (!this.root) return;
    const raw = this.git(["status", "--porcelain=v1", "-z", "--untracked-files=all"]);
    const fields = raw.split("\0");
    const files = [];
    for (let i = 0; i < fields.length && fields[i]; i += 1) {
      const entry = fields[i];
      const status = entry.slice(0, 2);
      const filePath = entry.slice(3);
      let oldPath;
      if (status.includes("R") || status.includes("C")) oldPath = fields[++i];
      files.push({ status, path: filePath, oldPath });
    }
    this.files = files;
    this.documents.clear();
    this.fileEmitter.fire();
    this.commentEmitter.fire();
  }

  fileStatus(item) {
    if (item.status === "??" || item.status.includes("A")) return "A";
    if (item.status.includes("D")) return "D";
    if (item.status.includes("R")) return "R";
    return "M";
  }

  makeUri(scheme, item) {
    const id = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
    const uri = vscode.Uri.from({ scheme, path: "/" + item.path, query: id });
    let content = "";
    if (scheme === BEFORE_SCHEME) {
      try { content = this.git(["show", `HEAD:${item.oldPath || item.path}`]); } catch (_) { content = ""; }
    } else {
      try { content = fs.readFileSync(path.join(this.root, item.path), "utf8"); } catch (_) { content = ""; }
    }
    this.documents.set(uri.toString(), { content, item, side: scheme === BEFORE_SCHEME ? "before" : "after" });
    return uri;
  }

  async openDiff(item) {
    const before = this.makeUri(BEFORE_SCHEME, item);
    const after = this.makeUri(AFTER_SCHEME, item);
    await vscode.commands.executeCommand("vscode.diff", before, after, `${this.fileStatus(item)} ${item.path} (HEAD ↔ Working Tree)`, {
      preview: true,
      preserveFocus: false,
    });
  }

  documentInfo(uri) {
    return this.documents.get(uri.toString());
  }
}

class FileProvider {
  constructor(state) { this.state = state; this.onDidChangeTreeData = state.fileEmitter.event; }
  getTreeItem(item) {
    const status = this.state.fileStatus(item);
    const tree = new vscode.TreeItem(item.path, vscode.TreeItemCollapsibleState.None);
    tree.description = status;
    tree.tooltip = `${status} ${item.path}`;
    tree.iconPath = new vscode.ThemeIcon(status === "A" ? "diff-added" : status === "D" ? "diff-removed" : status === "R" ? "diff-renamed" : "diff-modified");
    tree.command = { command: "claudeReview.openFile", title: "Open Diff", arguments: [item] };
    return tree;
  }
  getChildren() { return this.state.files; }
}

class CommentProvider {
  constructor(state) { this.state = state; this.onDidChangeTreeData = state.commentEmitter.event; }
  getTreeItem(comment) {
    const item = new vscode.TreeItem(`${comment.path}:${comment.line}`, vscode.TreeItemCollapsibleState.None);
    item.description = comment.text;
    item.tooltip = comment.text;
    item.iconPath = new vscode.ThemeIcon("comment");
    item.command = { command: "vscode.open", title: "Show Comment", arguments: [comment.uri, { selection: comment.range }] };
    return item;
  }
  getChildren() { return this.state.comments; }
}

function activate(context) {
  const state = new ReviewState();
  const contentProvider = { onDidChange: new vscode.EventEmitter().event, provideTextDocumentContent: uri => state.documentInfo(uri)?.content || "" };
  context.subscriptions.push(vscode.workspace.registerTextDocumentContentProvider(BEFORE_SCHEME, contentProvider));
  context.subscriptions.push(vscode.workspace.registerTextDocumentContentProvider(AFTER_SCHEME, contentProvider));
  context.subscriptions.push(vscode.window.registerTreeDataProvider("claudeReview.files", new FileProvider(state)));
  context.subscriptions.push(vscode.window.registerTreeDataProvider("claudeReview.comments", new CommentProvider(state)));

  const controller = vscode.comments.createCommentController("claudeReview", "Claude Review");
  context.subscriptions.push(controller);

  context.subscriptions.push(vscode.commands.registerCommand("claudeReview.openFile", item => state.openDiff(item)));
  context.subscriptions.push(vscode.commands.registerCommand("claudeReview.refresh", () => state.refresh()));

  context.subscriptions.push(vscode.commands.registerCommand("claudeReview.addComment", async () => {
    const editor = vscode.window.activeTextEditor;
    const info = editor && state.documentInfo(editor.document.uri);
    if (!editor || !info) {
      vscode.window.showWarningMessage("Claude Reviewのdiffでコメント対象行を選択してください");
      return;
    }
    const line = editor.selection.active.line;
    const text = await vscode.window.showInputBox({ prompt: `${info.item.path}:${line + 1} へのレビューコメント`, placeHolder: "Claude Codeへの修正依頼" });
    if (!text) return;
    const range = new vscode.Range(line, 0, line, Math.max(0, editor.document.lineAt(line).text.length));
    const thread = controller.createCommentThread(editor.document.uri, range, [{
      body: new vscode.MarkdownString(text),
      mode: vscode.CommentMode.Preview,
      author: { name: "You" },
    }]);
    thread.label = "Claude Codeへのレビュー";
    const comment = { path: info.item.path, side: info.side, line: line + 1, text, uri: editor.document.uri, range, thread };
    state.comments.push(comment);
    state.commentEmitter.fire();
  }));

  context.subscriptions.push(vscode.commands.registerCommand("claudeReview.deleteComment", thread => {
    const index = state.comments.findIndex(comment => comment.thread === thread);
    if (index >= 0) {
      state.comments[index].thread.dispose();
      state.comments.splice(index, 1);
      state.commentEmitter.fire();
    }
  }));

  context.subscriptions.push(vscode.commands.registerCommand("claudeReview.clearComments", () => {
    state.comments.forEach(comment => comment.thread.dispose());
    state.comments = [];
    state.commentEmitter.fire();
  }));

  context.subscriptions.push(vscode.commands.registerCommand("claudeReview.send", async () => {
    if (!state.comments.length) {
      vscode.window.showInformationMessage("送信するレビューコメントがありません");
      return;
    }
    const lines = ["以下のレビューコメントに対応してください。", ""];
    for (const comment of state.comments) {
      const side = comment.side === "after" ? "変更後" : "変更前";
      lines.push(`- ${comment.path}:${comment.line}（${side}）: ${comment.text}`);
    }
    const wezterm = "/Applications/WezTerm.app/Contents/MacOS/wezterm";
    const result = cp.spawnSync(wezterm, ["cli", "send-text", "--pane-id", state.paneId, lines.join("\n")]);
    if (result.status !== 0) {
      vscode.window.showErrorMessage("Claude Codeへのレビュー転送に失敗しました");
      return;
    }
    vscode.window.showInformationMessage(`${state.comments.length}件のレビューコメントをClaude Codeへ下書き転送しました`);
  }));

  context.subscriptions.push(vscode.window.registerUriHandler({
    async handleUri(uri) {
      try {
        const params = new URLSearchParams(uri.query);
        state.setSession(params.get("root"), params.get("pane"));
        await vscode.commands.executeCommand("workbench.view.extension.claudeReview");
        if (state.files.length) await state.openDiff(state.files[0]);
      } catch (error) {
        vscode.window.showErrorMessage(`Claude Reviewを開始できません: ${error.message}`);
      }
    },
  }));
}

function deactivate() {}

module.exports = { activate, deactivate };
