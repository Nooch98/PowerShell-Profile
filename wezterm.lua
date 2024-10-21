-- Pull in the weztern API
local wezterm = require 'wezterm'
local act = wezterm.action

-- This will hold the configuration
local config = wezterm.config_builder()

-- This is where is my config apply
config.default_prog = {'pwsh'}
config.color_scheme = 'tokyonight_moon'
config.font = wezterm.font('CaskaydiaMono Nerd Font')
config.font_size = 11
config.window_decorations = "RESIZE"
config.enable_tab_bar = true
config.window_background_opacity = 0.9
config.macos_window_background_blur = 10
config.tab_bar_at_bottom = true
config.default_cursor_style = 'SteadyBar'
config.harfbuzz_features = { 'liga', 'zero', 'kern', 'clig' }
config.hide_tab_bar_if_only_one_tab = true
config.window_padding = {
  left = 3, right = 3,
  top = 3, bottom =3,
}
config.inactive_pane_hsb = {
  saturation = 0.9,
  brightness = 0.6,
}
config.use_fancy_tab_bar = true
config.tab_max_width = 30

config.colors = {
  tab_bar = {
    -- Color de fondo general de la barra de pestañas
      background = "#1a1b26",  -- Fondo del tema Tokyo Night Moon

      -- Pestaña activa
      active_tab = {
        bg_color = "#7aa2f7",   -- Azul brillante
        fg_color = "#c0caf5",   -- Texto claro
        italic = true,
      },

      -- Pestañas inactivas
      inactive_tab = {
        bg_color = "#3b4261",  -- Azul oscuro
        fg_color = "#a9b1d6",  -- Texto gris claro
      },

      -- Hover en pestañas inactivas
      inactive_tab_hover = {
        bg_color = "#7dcfff",  -- Cian claro
        fg_color = "#c0caf5",  -- Texto claro
      },

      -- Nueva pestaña
      new_tab = {
        bg_color = "#bb9af7",  -- Púrpura claro
        fg_color = "#1a1b26",  -- Texto oscuro
    },
  },
},

-- Títulos dinámicos en las pestañas
wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local pane = tab.active_pane
  local title = tab.tab_index + 1 .. ": " ..pane.title

  if tab.is_active then
    return {
      { Text = "🌙 " .. title .. " "},
    }
  end
  return {
    { Text = "💤 " .. title .. " "},
  }
end)

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

return config
