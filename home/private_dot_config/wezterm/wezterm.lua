local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

config.default_cwd = wezterm.home_dir .. "/workspace"

-- Appearance
config.font = wezterm.font("HackGen Console", {
	weight = "Regular",
	stretch = "Normal",
	style = "Normal",
})
config.font_size = 15.0
config.color_scheme = "Ef-Night"
config.window_background_opacity = 0.8
config.macos_window_background_blur = 20
config.window_decorations = "RESIZE"

config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false
config.show_new_tab_button_in_tab_bar = false
config.colors = {
	tab_bar = {
		background = wezterm.color.get_builtin_schemes()[config.color_scheme].background,
		inactive_tab_edge = "none",
	},
}

wezterm.on("format-tab-title", function(tab)
	local scheme = wezterm.color.get_builtin_schemes()[config.color_scheme]
	local foreground = tab.is_active and scheme.brights[8] or scheme.foreground

	return {
		{ Background = { Color = scheme.background } },
		{ Foreground = { Color = foreground } },
	}
end)

wezterm.on("update-right-status", function(window)
	window:set_right_status("Cmd+/  ヘルプ")
end)

-- Claude Code sessions (see docs/wezterm.md, "cst")
local cst = wezterm.home_dir .. "/.config/scripts/cst"
local creview = wezterm.home_dir .. "/.config/scripts/creview"
local creview_code = wezterm.home_dir .. "/.config/scripts/creview-code"
local state_labels = { busy = "作業中  ", waiting = "許可待ち", idle = "入力待ち" }

local function project_dir(pane)
	local cwd_uri = pane:get_current_working_dir()
	if not cwd_uri then
		return nil
	end

	local cwd = cwd_uri.file_path
	local ok, stdout = wezterm.run_child_process({ "git", "-C", cwd, "rev-parse", "--show-toplevel" })
	if ok then
		return stdout:gsub("%s+$", "")
	end
	return cwd
end

local function truncate_utf8(s, max_chars)
	if utf8.len(s) and utf8.len(s) > max_chars then
		return s:sub(1, utf8.offset(s, max_chars + 1) - 1) .. "…"
	end
	return s
end

local function claude_session_choices(current_pane_id)
	local ok, stdout = wezterm.run_child_process({ cst, "--json" })
	if not ok then
		return nil
	end

	local choices = {}
	for line in stdout:gmatch("[^\n]+") do
		local parsed, s = pcall(wezterm.json_parse, line)
		if parsed and type(s) == "table" then
			local has_pane = type(s.pane_id) == "number"
			local mark = (has_pane and s.pane_id == current_pane_id) and "*" or " "
			local place = s.branch ~= "" and (s.dir .. " (" .. s.branch .. ")") or s.dir
			local detail = s.tool ~= "" and s.tool or truncate_utf8(s.prompt, 50)
			table.insert(choices, {
				id = has_pane and tostring(s.pane_id) or "",
				label = string.format("%s %s  %s  │  %s", mark, state_labels[s.state] or s.state, place, detail),
			})
		end
	end
	return choices
end

-- Input
config.use_ime = true

config.keys = {
	{
		key = "/",
		mods = "CMD",
		action = act.InputSelector({
			title = "WezTerm ショートカット",
			description = "Escで閉じる",
			choices = {
				{ label = "Cmd+Shift+Space   現在のプロジェクトをVS Codeで開く" },
				{ label = "Cmd+Shift+R       変更ファイルを全画面でレビュー" },
				{ label = "Cmd+Shift+D       VS Codeで変更をレビュー" },
				{ label = "wlay diff          Git差分をテキストで開く" },
				{ label = "Cmd+;             Claude Code セッション一覧（選択でペインへ移動）" },
				{ label = "Cmd+W             現在のペインを閉じる" },
				{ label = "Cmd+,             ペインを縦分割" },
				{ label = "Cmd+.             ペインを横分割" },
				{ label = "Shift+Enter       改行を送信" },
				{ label = "Cmd+T             新しいタブを開く" },
				{ label = "マウスドラッグ    テキストを選択してコピー" },
			},
			action = wezterm.action_callback(function() end),
		}),
	},
	{
		key = "Space",
		mods = "CMD|SHIFT",
		action = wezterm.action_callback(function(window, pane)
			local cwd = project_dir(pane)
			if not cwd then
				window:toast_notification("WezTerm", "Could not detect the current directory", nil, 3000)
				return
			end

			wezterm.background_child_process({ "/usr/bin/open", "-a", "Visual Studio Code", cwd })
		end),
	},
	{
		key = "d",
		mods = "CMD|SHIFT",
		action = wezterm.action_callback(function(window, pane)
			local cwd = project_dir(pane)
			if not cwd then
				window:toast_notification("WezTerm", "Could not detect the current directory", nil, 3000)
				return
			end

			wezterm.background_child_process({
				creview_code,
				"--root",
				cwd,
				"--claude-pane",
				tostring(pane:pane_id()),
			})
		end),
	},
	{
		key = "r",
		mods = "CMD|SHIFT",
		action = wezterm.action_callback(function(window, pane)
			local cwd = project_dir(pane)
			if not cwd then
				window:toast_notification("WezTerm", "Could not detect the current directory", nil, 3000)
				return
			end

			window:perform_action(
				act.SpawnCommandInNewTab({
					args = { creview, "--root", cwd, "--claude-pane", tostring(pane:pane_id()) },
					cwd = cwd,
				}),
				pane
			)
		end),
	},
	{
		key = ";",
		mods = "CMD",
		action = wezterm.action_callback(function(window, pane)
			local choices = claude_session_choices(pane:pane_id())
			if choices == nil then
				window:toast_notification("WezTerm", "cst の実行に失敗しました", nil, 3000)
				return
			end
			if #choices == 0 then
				window:toast_notification("WezTerm", "Claude Code のセッションはありません", nil, 3000)
				return
			end
			window:perform_action(
				act.InputSelector({
					title = "Claude Code セッション",
					description = "Enter でそのペインへ移動 / Esc で閉じる",
					fuzzy = false,
					choices = choices,
					action = wezterm.action_callback(function(_, _, id)
						if id == nil or id == "" then
							return
						end
						local target = wezterm.mux.get_pane(tonumber(id))
						if target then
							target:activate()
						end
					end),
				}),
				pane
			)
		end),
	},
	{
		key = "w",
		mods = "CMD",
		action = act.CloseCurrentPane({ confirm = true }),
	},
	{
		key = ",",
		mods = "CMD",
		action = act({ SplitVertical = { domain = "CurrentPaneDomain" } }),
	},
	{
		key = ".",
		mods = "CMD",
		action = act({ SplitHorizontal = { domain = "CurrentPaneDomain" } }),
	},
	{
		key = "Enter",
		mods = "SHIFT",
		action = act.SendString("\n"),
	},
}

-- Select and copy with the mouse even when an application enables mouse
-- reporting on the primary screen. Alternate-screen applications keep their
-- own mouse handling.
local function selection_mouse_bindings()
	local bindings = {}

	for streak, mode in ipairs({ "Cell", "Word", "Line" }) do
		table.insert(bindings, {
			event = { Down = { streak = streak, button = "Left" } },
			mods = "NONE",
			action = act.SelectTextAtMouseCursor(mode),
			mouse_reporting = true,
			alt_screen = false,
		})
		table.insert(bindings, {
			event = { Up = { streak = streak, button = "Left" } },
			mods = "NONE",
			action = act.CompleteSelection("ClipboardAndPrimarySelection"),
			mouse_reporting = true,
			alt_screen = false,
		})
	end

	table.insert(bindings, {
		event = { Drag = { streak = 1, button = "Left" } },
		mods = "NONE",
		action = act.ExtendSelectionToMouseCursor("Cell"),
		mouse_reporting = true,
		alt_screen = false,
	})

	return bindings
end

config.mouse_bindings = selection_mouse_bindings()

return config
