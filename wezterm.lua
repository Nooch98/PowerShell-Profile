local wezterm = require 'wezterm'
local act = wezterm.action

-- This will hold the configuration
local config = {}

if wezterm.config_builder then config =  wezterm.config_builder() end

-- This is where is my config apply
config.default_prog = {'pwsh'}
config.color_scheme = 'Tokyo Night'
config.font = wezterm.font('CaskaydiaMono Nerd Font')
config.font_size = 11
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
    key = 'h',
    mods = 'ALT|SHIFT',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    -- Crear un panel en vertical
    key = 'v',
    mods = 'ALT|SHIFT',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain'},
  },
  {
    -- Moverme al panel de la izquierda
    key = 'LeftArrow',
    mods = 'ALT',
    action = act.ActivatePaneDirection 'Left',
  },
  {
    -- Moverme al panel de la derecha
    key = 'RightArrow',
    mods = 'ALT',
    action = act.ActivatePaneDirection 'Right',
  },
  {
    -- Moverme al panel de arriba
    key = 'UpArrow',
    mods = 'ALT',
    action = act.ActivatePaneDirection 'Up',
  },
  {
    -- Moverme al panel de abajo
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
  -- Shortcuts para resize de los paneles
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
wezterm.on("update-status", function(window, pane)
  local stat = window:active_workspace()
  local stat_color = "#f7768e"
  if window:active_key_table() then stat = window:active_key_table() stat_color = "#7dcfff" end
  if window:leader_is_active() then stat = "LDR" stat_color = "#bb9af7" end
  local basename = function(s)
    return string.gsub(s, "(.*[/\\])(.*))", "%2")
  end
  local cwd = pane:get_current_working_dir()
  if cwd then
    if type(cwd) == "userdata" then
      cwd = basename(cwd.file_path)
    else
      cwd = basename(cwd)
    end
  else
    cwd = ""
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
