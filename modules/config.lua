-- Walkbot by ShadyRetard

local config = {}

config.modules = {
    "gui",
    "map_manager",
    "mesh_manager",
    "debug",
    "mesh_navigation",
    "objective",
    "objective_use",
    "movement",
    "memory",
    "autoqueue"
}
config.main_directory = "walkbot"
config.data_directory = config.main_directory .. "\\data"               -- Path to the data folder
config.modules_directory = config.main_directory .. "\\modules"         -- Path to the module folder
config.data_download_url = "https://raw.githubusercontent.com/ShadyRetard/aimware_walkbot_data/master"
config.core_download_url = "https://raw.githubusercontent.com/ShadyRetard/aimware_walkbot/master"
config.tab_width = 640                                                  -- Width for a tab, defaults to 640
config.tab_padding = 16                                                 -- Width for padding around items, defaults to 16
config.debug_x = 16                                                     -- x position for debug
config.debug_y = 16                                                     -- y position for debug
config.debug_width = 200                                                -- Width for debug
config.memory_time = 3                                                  -- How long walkbot keeps its player memory for
config.objective_switching_time = 10                                    -- How often the objective can be changed in seconds

return config