-- Pull in the wezterm API
local wezterm = require("wezterm")
local config = wezterm.config_builder()
local act = wezterm.action

config.automatically_reload_config = true
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- start new windows / tabs in ~/workspace
config.default_cwd = wezterm.home_dir .. "/workspace"

-- set leader
config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 2001 }

-- font size
config.font_size = 15.0
config.font = wezterm.font("Hack Nerd Font", { weight = "Regular", stretch = "Normal", style = "Normal" })

-- right status
wezterm.on("update-right-status", function(window)
	window:set_right_status(window:active_workspace())
end)

-- use jp lang
config.use_ime = true

-- opacity
config.window_background_opacity = 0.8
config.macos_window_background_blur = 20

-- color scheme
-- config.color_scheme = 'Aci (Gogh)'
-- config.color_scheme = 'Ef-Deuteranopia-Dark'
-- config.color_scheme = 'ENCOM'
config.color_scheme = "Ef-Night"
-- config.color_scheme = 'Blue Matrix'

-- tab bar
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false
config.window_decorations = "RESIZE"
config.show_new_tab_button_in_tab_bar = false
config.tab_bar_at_bottom = false
config.colors = {
	tab_bar = {
		inactive_tab_edge = "none",
	},
}

wezterm.on("format-tab-title", function(tab)
		local scheme = wezterm.color.get_builtin_schemes()[config.color_scheme]
		local background = scheme.background
		local foreground = scheme.foreground

		if tab.is_active then
			foreground = scheme.brights[8]
		end

		return {
			{ Background = { Color = background } },
			{ Foreground = { Color = foreground } },
		}
	end)

-- tab bar color asnc color_scheme
config.colors = {
	tab_bar = {
		background = wezterm.color.get_builtin_schemes()[config.color_scheme].background,
	},
}

config.keys = {
	-- reload
	{
		key = "r",
		mods = "CMD|SHIFT",
		action = wezterm.action.ReloadConfiguration,
 },
	-- close tab
	{
		key = "w",
		mods = "CMD",
		action = act.CloseCurrentPane({ confirm = true }),
	},
	-- pane split
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
	-- pane move (SHIFT + Arrow)
	{
		key = "LeftArrow",
		mods = "SHIFT",
		action = act.ActivatePaneDirection("Left"),
	},
	{
		key = "RightArrow",
		mods = "SHIFT",
		action = act.ActivatePaneDirection("Right"),
	},
	{
		key = "UpArrow",
		mods = "SHIFT",
		action = act.ActivatePaneDirection("Up"),
	},
	{
		key = "DownArrow",
		mods = "SHIFT",
		action = act.ActivatePaneDirection("Down"),
	},
	-- workspace (CMD + Left/Right)
	{
		key = "LeftArrow",
		mods = "CMD",
		action = act.SwitchWorkspaceRelative(-1),
	},
	{
		key = "RightArrow",
		mods = "CMD",
		action = act.SwitchWorkspaceRelative(1),
	},
	{
		key = "9",
		mods = "ALT",
		action = act.ShowLauncherArgs({
			flags = "FUZZY|WORKSPACES",
		}),
	},
	{ key = "Enter", mods = "SHIFT", action = act.SendString("\n") },
  {
    key = 'n',
    mods = 'CTRL',
    action = wezterm.action.TogglePaneZoomState,
  },
}

-- mouse selection
-- Plain left-drag selects & copies even while the running program has mouse
-- reporting enabled, as long as it is on the primary screen (Claude Code, shell).
-- Alt-screen apps (nvim, lazygit, fzf) keep receiving mouse events as before.
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
