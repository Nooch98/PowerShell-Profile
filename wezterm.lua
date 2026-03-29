local wezterm = require 'wezterm'
local theme = wezterm.plugin.require('https://github.com/neapsix/wezterm').main
local act = wezterm.action
local config = {}

if wezterm.config_builder then config =  wezterm.config_builder() end

config.default_prog = {'pwsh'}
config.colors = theme.colors()
config.window_frame = theme.window_frame()
config.font = wezterm.font('FiraCode Nerd Font')
config.font_size = 10
config.window_background_opacity = 0.9
config.window_decorations = "RESIZE"
config.default_workspace = "home"
config.default_cursor_style = 'SteadyBar'
config.inactive_pane_hsb = {
  saturation = 0.5,
  brightness = 0.5,
}

-- KeyBinding configuration
config.keys = {
  {
    -- Crear un panel en horizontal
    key = 'd',
    mods = 'ALT|SHIFT',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    -- Create a vertical panel
    key = 's',
    mods = 'ALT|SHIFT',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain'},
  },
  {
    key = 'z',
    mods = 'CTRL|SHIFT',
    action = act.TogglePaneZoomState,
  },
  {
    -- Move to the left panel
    key = 'LeftArrow',
    mods = 'ALT',
    action = act.ActivatePaneDirection 'Left',
  },
  {
    -- Move to the right panel
    key = 'RightArrow',
    mods = 'ALT',
    action = act.ActivatePaneDirection 'Right',
  },
  {
    -- Move to the top panel
    key = 'UpArrow',
    mods = 'ALT',
    action = act.ActivatePaneDirection 'Up',
  },
  {
    -- Move to the panel below
    key = 'DownArrow',
    mods = 'ALT',
    action = act.ActivatePaneDirection 'Down',
  },
  {
    key = 't',
    mods = 'SHIFT|ALT',
    action = act.SpawnTab 'CurrentPaneDomain',
  },
  {
    key = 'n',
    mods = 'ALT',
    action = wezterm.action.ShowTabNavigator,
  },
  {
    key = 'l',
    mods = 'ALT',
    action = wezterm.action.ShowLauncherArgs {flags = 'TABS|WORKSPACES'},
  },
  {
    key = 'b',
    mods = 'CTRL',
    action = act.RotatePanes 'CounterClockwise',
  },
  {
    key = 'q',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.CloseCurrentPane { confirm = true},
  },
  {
    key = 'f',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.ToggleFullScreen
  },
  {
    key = 'LeftArrow',
    mods = 'ALT|SHIFT',
    action = act.ActivateTabRelative(-1)
  },
  {
    key = 'RightArrow',
    mods = 'ALT|SHIFT',
    action = act.ActivateTabRelative(1)
  },
  -- Shortcuts for resizing panels
  {
    key = 'LeftArrow',
    mods = 'CTRL|ALT',
    action = act.AdjustPaneSize {'Left', 5},
  },
  {
    key = 'RightArrow',
    mods = 'CTRL|ALT',
    action = act.AdjustPaneSize {'Right', 5},
  },
  {
    key = 'UpArrow',
    mods = 'CTRL|ALT',
    action = act.AdjustPaneSize {'Up', 5},
  },
  {
    key = 'DownArrow',
    mods = 'CTRL|ALT',
    action = act.AdjustPaneSize {'Down', 5},
  }
}

config.use_fancy_tab_bar = false
config.status_update_interval = 1000
config.tab_bar_at_bottom = false
local basename = function(s)
  if s then
    local result = s:match('.*[/\\](.*)')
    return result or s
  end
  return ""
end
wezterm.on("update-status", function(window, pane)
  local stat = window:active_workspace()
  local stat_color = "#f7768e"
  if window:active_key_table() then stat = window:active_key_table() stat_color = "#7dcfff" end
  if window:leader_is_active() then stat = "LDR" stat_color = "#bb9af7" end
  local cwd_uri = pane:get_current_working_dir()
  local cwd_path = wezterm.uri.file_path(cwd_uri)
  local cwd = ''
  if cwd_path then
    local result = cwd_path:match('.*[/\\](.*)')
    cwd = result or cwd_path
  end
  local cmd = pane:get_foreground_process_name()
  cmd = cmd and basename(cmd) or ""
  local time = wezterm.strftime("%H:%M")

  window:set_left_status(wezterm.format({
    { Foreground = { Color = stat_color} },
    { Text = "  "},
    { Text = wezterm.nerdfonts.oct_table .. "  " .. stat },
    { Text = " |" },
  }))

  window:set_right_status(wezterm.format{
    { Text = wezterm.nerdfonts.md_folder .. " " .. cwd },
    { Text = " | " },
    { Foreground = { Color = "#e0af68" }},
    { Text = wezterm.nerdfonts.fa_code .. " " .. cmd },
    "ResetAttributes",
    { Text = " | " },
    { Text = wezterm.nerdfonts.md_clock .. " " .. time },
    { Text = "  " },
  })
end)
return config
	
