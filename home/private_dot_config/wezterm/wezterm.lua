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
				{ label = "Cmd+Shift+Space   現在のディレクトリをVS Codeで開く" },
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
			local cwd_uri = pane:get_current_working_dir()
			if not cwd_uri then
				window:toast_notification("WezTerm", "Could not detect the current directory", nil, 3000)
				return
			end

			local cwd = cwd_uri.file_path
			wezterm.background_child_process({ "/usr/bin/open", "-a", "Visual Studio Code", cwd })
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
