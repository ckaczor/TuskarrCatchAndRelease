local ADDON_NAME, private = ...

TuskarrRestockTracker = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local LibQTip = LibStub("LibQTip-1.0")
local LibDBIcon = LibStub("LibDBIcon-1.0")
local AceConfig = LibStub("AceConfig-3.0")

local _

local defaults = {
    global = {
        sort_field = "NAME",
        sort_dir = "ASC",
        minimap_icon = {
            hide = false
        }
    }
}

local options = {
    name = L["Tuskarr Restock Tracker"],
    type = "group",
    args = {
        minimap_icon = {
            order = 1,
            type = "toggle",
            name = L["Show minimap icon"],
            desc = L["Shows or hides the minimap icon"],
            get = function()
                return not private.db.global.minimap_icon.hide
            end,
            set = function(info, value)
                private.db.global.minimap_icon.hide = not value
                TuskarrRestockTracker:UpdateMinimapConfig()
            end
        }
    }
}

local LDB = LibStub("LibDataBroker-1.1"):NewDataObject(ADDON_NAME, {
    type = "data source",
    icon = "Interface\\Icons\\Inv_fishing_netlinen01",
    label = L["Tuskarr Restock Tracker"],
    text = L["Tuskarr Restock Tracker"],
    OnClick = function(clickedframe, button)
        if not private.loaded then
            return
        end

        if button == "LeftButton" then
            if (private.pinned) then
                private.tooltip:SetAutoHideDelay(0.25, self)

                private.pinned = false
            else
                private.tooltip:SetAutoHideDelay()

                private.pinned = true
            end
        elseif button == "RightButton" then
            private.need_index = private.need_index + 1

            TuskarrRestockTracker:UpdateText()
        end
    end
})

function TuskarrRestockTracker:OnInitialize()
    private.pinned = false
    private.need_index = 1
    private.loaded = false
    private.item_name_table = {}

    -- Create the database with defaults
    private.db = LibStub("AceDB-3.0"):New("TuskarrRestockTrackerDB", defaults)

    -- Register options
    AceConfig:RegisterOptionsTable(ADDON_NAME, options, {"/trt"})

    -- Add to the options frame
    private.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(ADDON_NAME, L["Tuskarr Restock Tracker"])

    -- Register a chat command
    self:RegisterChatCommand("trt", "ChatCommand")

    -- Register the minimap icon
    LibDBIcon:Register(ADDON_NAME, LDB, private.db.global.minimap_icon)
end

function TuskarrRestockTracker:OnEnable()
    -- Disable if the player is less than 10
    if (UnitLevel("player") < 10) then
        LDB.text = L["Disabled until level 10"]

        -- Register to get player level events
        self:RegisterEvent("PLAYER_LEVEL_UP")

        return
    end

    -- Do the real enable
    TuskarrRestockTracker:OnEnableCore()
end

function TuskarrRestockTracker:PLAYER_LEVEL_UP(event, newLevel)
    if (tonumber(newLevel) >= 10) then
        -- Do the real enable
        TuskarrRestockTracker:OnEnableCore()

        -- Done with player level events
        self:UnregisterEvent("PLAYER_LEVEL_UP")
    end
end

function TuskarrRestockTracker:OnEnableCore()
    -- Show loading text
    TuskarrRestockTracker:Print(L["Loading..."])
    LDB.text = L["Loading..."]

    -- Load item info from cache
    TuskarrRestockTracker:LoadCache()
end

function TuskarrRestockTracker:LoadCache()
    local item_count = 0
    local item_loaded_count = 0
    local item_table = {}

    private.item_name_table = {}

    -- Loop over each quest in the data	
    for _, quest_info in pairs(private.QUESTS) do

        -- Get the item ID of the fish
        local fish_id = quest_info["FISH_ID"]

        -- Add the fish to the list of items
        item_table[fish_id] = Item:CreateFromItemID(fish_id)
        item_count = item_count + 1
    end

    -- Loop over all items we need to cache
    for _, item in pairs(item_table) do

        -- Wait for the item to load
        item:ContinueOnItemLoad(function()

            -- Save the name
            private.item_name_table[item:GetItemID()] = item:GetItemName()
            item_loaded_count = item_loaded_count + 1

            -- If everything is cached we're good to go
            if (item_count == item_loaded_count) then
                TuskarrRestockTracker:OnLoaded(self)
            end
        end)
    end
end

function TuskarrRestockTracker:OnLoaded(self)
    -- Show loaded text
    TuskarrRestockTracker:Print(L["Loaded"])
    LDB.text = L["Loaded"]

    self:RegisterEvent("QUEST_LOG_UPDATE")
    self:RegisterEvent("BAG_UPDATE")

    TuskarrRestockTracker:UpdateData()
    TuskarrRestockTracker:UpdateText()

    private.loaded = true
end

local function SetSort(cell, sort)
    if private.db.global.sort_field == sort then
        if (private.db.global.sort_dir == "ASC") then
            private.db.global.sort_dir = "DESC"
        else
            private.db.global.sort_dir = "ASC"
        end
    else
        private.db.global.sort_field = sort
        private.db.global.sort_dir = "ASC"
    end

    if not private.loaded then
        return
    end

    TuskarrRestockTracker:UpdateData()
    TuskarrRestockTracker:UpdateTooltip()
end

function TuskarrRestockTracker:UpdateData()

    -- Create a table to store all needs
    private.need_table = {}
    private.need_count = 0

    -- Create a table to hold the information to display for each quest
    private.quest_table = {}
    private.quest_count = 0

    -- Loop over each quest in the data
    for quest_id, quest_info in pairs(private.QUESTS) do

        -- Check if the quest is completed
        local is_completed = C_QuestLog.IsQuestFlaggedCompleted(quest_id)

        -- Get the ID of the fish required for this quest
        local fish_id = quest_info["FISH_ID"]

        -- Get the name of the fish for display
        local fish_name = private.item_name_table[fish_id]

        -- Get how many of the fish we have in our bags
        local fish_count = GetItemCount(fish_id, true, false)

        -- Get the number of items required
        local required_count = quest_info["FISH_COUNT"]

        -- Color the fish count based on whether there is enough in the bags or not
        local fish_count_display =
            (fish_count >= required_count) and "|cFF00FF00" .. fish_count .. "|r" or "|cFFFFFF00" .. fish_count .. "|r"

        -- Initialize need and status strings
        local need_count = 0
        local quest_status = ""
        local can_craft = 0

        -- Figure out how many of the fish we need to get to what we need
        need_count = (fish_count < required_count) and required_count - fish_count or 0

        if (is_completed) then
            -- Quest has already been completed today
            quest_status = L["|cFF00FF00Complete|r"]
        else
            -- Quest still needs to be done
            quest_status = L["|cFFFF0000Not Complete|r"]

            private.need_table[quest_id] = need_count
            private.need_count = private.need_count + 1
        end

        -- Insert everything we figured out into the quest table
        table.insert(private.quest_table, {
            NAME = quest_info["NAME"],
            NAME_DISPLAY = "|cffeda55f" .. quest_info["NAME"] .. "|r",
            FISH = fish_name,
            FISH_DISPLAY = fish_name,
            AMOUNT = fish_count,
            AMOUNT_DISPLAY = fish_count_display,
            STATUS = quest_status,
            NEED = need_count
        })

        private.quest_count = private.quest_count + 1
    end

    -- Sort the quest table using the sort field and direction from the settings	
    table.sort(private.quest_table,
        private.SORT_FUNCTIONS[private.db.global.sort_field .. "_" .. private.db.global.sort_dir])
end

function TuskarrRestockTracker:UpdateTooltip()
    if LibQTip:IsAcquired(ADDON_NAME) then
        private.tooltip:Clear()
    else
        private.tooltip = LibQTip:Acquire(ADDON_NAME, 5)

        private.tooltip:SetBackdropColor(0, 0, 0, 1)

        private.tooltip:SmartAnchorTo(private.LDB_ANCHOR)
        private.tooltip:SetAutoHideDelay(0.25, private.LDB_ANCHOR)
    end

    -- Add the header line and set the cell text and scripts
    local line = private.tooltip:AddHeader()

    private.tooltip:SetCell(line, 1, L["Quest"])
    private.tooltip:SetCellScript(line, 1, "OnMouseUp", SetSort, "NAME")

    private.tooltip:SetCell(line, 2, L["Fish"])
    private.tooltip:SetCellScript(line, 2, "OnMouseUp", SetSort, "FISH")

    private.tooltip:SetCell(line, 3, L["Have"])
    private.tooltip:SetCellScript(line, 3, "OnMouseUp", SetSort, "AMOUNT")

    private.tooltip:SetCell(line, 4, L["Status"])
    private.tooltip:SetCellScript(line, 4, "OnMouseUp", SetSort, "STATUS")

    private.tooltip:SetCell(line, 5, L["Need"])
    private.tooltip:SetCellScript(line, 5, "OnMouseUp", SetSort, "NEED")

    private.tooltip:AddSeparator()

    -- Loop over all quests in the sorted table
    for _, quest in pairs(private.quest_table) do

        -- Add the line with info about the current quest
        line = private.tooltip:AddLine(quest["NAME_DISPLAY"], quest["FISH_DISPLAY"], quest["AMOUNT_DISPLAY"],
            quest["STATUS"], quest["NEED"])
    end

    -- Add the normal usage hints
    private.tooltip:AddLine(" ")

    line = private.tooltip:AddLine()
    private.tooltip:SetCell(line, 1, L["|cFFFFFF00Click|r the main button to toggle whether the tooltip stays open"],
        "LEFT", private.tooltip:GetColumnCount())

    line = private.tooltip:AddLine()
    private.tooltip:SetCell(line, 1, L["|cFFFFFF00Right Click|r the main button to cycle through which quest to track"],
        "LEFT", private.tooltip:GetColumnCount())
end

function TuskarrRestockTracker:UpdateText()
    local need_index = 1

    if (private.need_index > private.need_count) then
        private.need_index = 1
    end

    if (private.need_count == 0) then
        LDB.text = L["Done"]
        return
    end

    -- Loop over the need table
    for quest_id, need_count in pairs(private.need_table) do
        if need_index == private.need_index then
            local fish_id = private.QUESTS[quest_id]["FISH_ID"]

            if need_count == 0 then
                LDB.text = L["Turn In:"] .. " " .. private.item_name_table[fish_id]
            else
                LDB.text = L["Gather:"] .. " " .. need_count .. " " .. private.item_name_table[fish_id]
            end

            return
        end

        need_index = need_index + 1
    end
end

function LDB.OnEnter(self)
    if not private.loaded then
        return
    end

    private.LDB_ANCHOR = self
    TuskarrRestockTracker:UpdateTooltip()

    private.tooltip:Show()
end

function TuskarrRestockTracker:QUEST_LOG_UPDATE()
    if not private.loaded then
        return
    end

    TuskarrRestockTracker:UpdateData()
    TuskarrRestockTracker:UpdateText()

    if not private.LDB_ANCHOR then
        return
    end

    TuskarrRestockTracker:UpdateTooltip()
end

function TuskarrRestockTracker:BAG_UPDATE()
    if not private.loaded then
        return
    end

    TuskarrRestockTracker:UpdateData()
    TuskarrRestockTracker:UpdateText()

    if not private.LDB_ANCHOR then
        return
    end

    TuskarrRestockTracker:UpdateTooltip()
end

function TuskarrRestockTracker:UpdateMinimapConfig()
    if private.db.global.minimap_icon.hide then
        LibDBIcon:Hide(ADDON_NAME)
    else
        LibDBIcon:Show(ADDON_NAME)
    end
end

function TuskarrRestockTracker:ChatCommand(input)

    local command, arg1 = self:GetArgs(input, 2)

    if (command == nil) then
        command = ""
    end

    command = command:lower()

    if command == L["config"]:lower() then
        InterfaceOptionsFrame_OpenToCategory(private.optionsFrame)
    elseif command == L["minimap"]:lower() then
        private.db.global.minimap_icon.hide = not private.db.global.minimap_icon.hide
        TuskarrRestockTracker:UpdateMinimapConfig()
    else
        TuskarrRestockTracker:Print(L["Available commands:"])
        TuskarrRestockTracker:Print("|cFF00C0FF" .. L["config"] .. "|r - " .. L["Show configuration"])
        TuskarrRestockTracker:Print("|cFF00C0FF" .. L["minimap"] .. "|r - " .. L["Toggles the minimap icon"])
    end
end
