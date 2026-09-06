local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

config.default_cwd = wezterm.home_dir .. "/workspace"

-- Appearance
config.font = wezterm.font("Hack Nerd Font", {
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

-- Input
config.use_ime = true

config.keys = {
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
