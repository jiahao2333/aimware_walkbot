local walkbot = {}
local is_downloading = false
local num_data_files_downloaded = 0
local num_data_files_available = 0
local num_data_files_failed = 0

local function download_files(path, local_directory)
    is_downloading = true
    local data_files = http.Get(path .. "/files.txt")

    for s in data_files:gmatch("[^\r\n]+") do
        num_data_files_available = num_data_files_available + 1
        http.Get(path .. "/" .. s, function(online_file_content)
            if (online_file_content == nil or online_file_content == "error") then
                num_data_files_failed = num_data_files_failed + 1
                return
            end

            num_data_files_downloaded = num_data_files_downloaded + 1
            file.Open(local_directory .. "\\" .. s, "w"):Write(online_file_content):Close()
        end)
    end
end

local core_version_file = file.Open(walkbot.config.main_directory .. "\\version.txt", "r")
local online_core_version = http.Get(walkbot.config.data_download_url .. "/version.txt")

walkbot.config = RunScript("walkbot\\modules\\config.lua")

if (walkbot.config == nil or core_version_file == nil or core_version_file:Read() ~= online_core_version) then
    download_files(walkbot.config.core_download_url, walkbot.config.main_directory)
end

walkbot.json = RunScript(walkbot.config.main_directory .. "\\json.lua")


local data_version_file = file.Open(walkbot.config.data_directory .. "\\version.txt", "r")
local online_data_version = http.Get(walkbot.config.data_download_url .. "/version.txt")

if (data_version_file == nil or online_data_version ~= data_version_file:Read()) then
    download_files(walkbot.config.data_download_url, walkbot.config.data_directory)
end

callbacks.Register("Draw", "walkbot_update_data_files", function()
    if (num_data_files_available ~= (num_data_files_downloaded + num_data_files_failed)) then
        draw.Text(0, 0, "[Walkbot Update] Downloading..." .. num_data_files_downloaded .. " / " .. num_data_files_available .. " files.")
    elseif (num_data_files_failed > 0) then
        draw.Text(0, 0, "[Walkbot Update] Downloads failed: " .. num_data_files_failed .. ", restart lua to try again.")
    else
        draw.Text(0, 0, "[Walkbot Update] Update completed, please restart lua to use walkbot.")
    end
end)

if (is_downloading == false) then
    callbacks.Unregister("Draw", "walkbot_update_core_files")
    callbacks.Unregister("Draw", "walkbot_update_data_files")

    for _, value in pairs(walkbot.config.modules) do
        walkbot[value] = RunScript(walkbot.config.modules_path .. "\\" .. value .. ".lua")
    end

    for _, value in pairs(walkbot.config.modules) do
        walkbot[value].connect(walkbot)
    end
end