-- SpellbookTab.lua — StatBooster Library tab in the Spellbook
-- Uses an unused SpellBookSkillLineTab slot (same pattern as WhatsTraining)
local _, SB = ...
local band = SB.band

-- ═══════════════════════════════════════
-- Constants
-- ═══════════════════════════════════════
local SKILL_LINE_TAB = (MAX_SKILLLINE_TABS or 8)  -- last available tab slot
local TAB_ICON = "Interface\\Icons\\INV_Enchant_EssenceEternalLarge"

local POOL_NAMES_RU = { "\208\145\208\190\208\181\208\178\208\190\208\185", "\208\151\208\176\209\137\208\184\209\130\208\189\209\139\208\185", "\208\162\208\176\208\185\208\189\209\139\208\185", "\208\163\208\180\208\176\209\135\208\184" }
local POOL_COLORS = { "|cffff4444", "|cff44ff44", "|cff4488ff", "|cffffcc00" }
local POOL_ICONS = {
    "Interface\\Icons\\INV_Stone_SharpeningStone_01",
    "Interface\\Icons\\INV_Misc_ArmorKit_17",
    "Interface\\Icons\\INV_Enchant_EssenceMagicLarge",
    "Interface\\Icons\\INV_Inscription_ScrollOfWisdom01",
}
local TIER_RANGES = { {1,25}, {26,45}, {46,65}, {66,92} }

local SLOT_FILTERS = {
    { mask = 0,       name = "All" },
    { mask = 2,       name = "Head" },
    { mask = 4,       name = "Neck" },
    { mask = 8,       name = "Shoulder" },
    { mask = 1048608, name = "Chest" },
    { mask = 64,      name = "Waist" },
    { mask = 128,     name = "Legs" },
    { mask = 256,     name = "Feet" },
    { mask = 512,     name = "Wrist" },
    { mask = 1024,    name = "Hands" },
    { mask = 2048,    name = "Finger" },
    { mask = 4096,    name = "Trinket" },
    { mask = 65536,   name = "Back" },
    { mask = 16384,   name = "Shield" },
    { mask = 8192,    name = "Weapon" },
    { mask = 131072,  name = "2H Weapon" },
}

-- ═══════════════════════════════════════
-- Filter state
-- ═══════════════════════════════════════
local filterPool = nil
local filterTier = nil
local filterSlot = 0
local filteredList = {}

local function BuildFilteredList()
    filteredList = {}
    local seen = {}

    for _, e in ipairs(SB.DB.Enchants) do
        if filterPool and e.pool ~= filterPool then
            -- skip
        else
            local tierOk = true
            if filterTier and filterTier >= 1 and filterTier <= 4 then
                local tMin, tMax = TIER_RANGES[filterTier][1], TIER_RANGES[filterTier][2]
                tierOk = (e.max >= tMin and e.min <= tMax)
            end

            local slotOk = true
            if filterSlot > 0 and e.mask and e.mask > 0 then
                slotOk = (band(e.mask, filterSlot) ~= 0)
            end

            if tierOk and slotOk then
                local key = e.pool .. ":" .. e.name
                if not seen[key] then
                    seen[key] = true
                    table.insert(filteredList, e)
                end
            end
        end
    end

    table.sort(filteredList, function(a, b)
        if a.pool ~= b.pool then return a.pool < b.pool end
        return a.name < b.name
    end)
end

-- ═══════════════════════════════════════
-- Deferred init — SpellBookFrame may not exist at load time
-- ═══════════════════════════════════════
local mainFrame = nil
local initialized = false

local function InitSpellbookTab()
if initialized then return end
if not SpellBookFrame then return end
initialized = true

-- ═══════════════════════════════════════
-- Main frame (covers full spellbook area)
-- ═══════════════════════════════════════
mainFrame = CreateFrame("Frame", "SB_LibraryFrame", SpellBookFrame)
mainFrame:SetPoint("TOPLEFT", SpellBookFrame, "TOPLEFT", 0, 0)
mainFrame:SetPoint("BOTTOMRIGHT", SpellBookFrame, "BOTTOMRIGHT", 0, 0)
mainFrame:SetFrameStrata("HIGH")
mainFrame:Hide()

-- Background
local bg = mainFrame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetTexture("Interface\\SpellBook\\SpellBook-Page-1")

-- Title
local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 20, -18)
title:SetText("StatBooster Library")

-- Sync status
local syncStatus = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
syncStatus:SetPoint("TOPRIGHT", -45, -22)

-- ═══════════════════════════════════════
-- Pool selector buttons
-- ═══════════════════════════════════════
local poolBtns = {}

for i = 1, 4 do
    local btn = CreateFrame("Button", nil, mainFrame)
    btn:SetSize(26, 26)
    btn:SetPoint("TOPLEFT", 30 + (i - 1) * 68, -42)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(22, 22)
    btn.icon:SetPoint("CENTER")
    btn.icon:SetTexture(POOL_ICONS[i])
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    btn.border = btn:CreateTexture(nil, "OVERLAY")
    btn.border:SetAllPoints()
    btn.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    btn.border:SetBlendMode("ADD")
    btn.border:SetAlpha(0)

    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.label:SetPoint("LEFT", btn, "RIGHT", 2, 0)
    btn.label:SetText(POOL_NAMES_RU[i])

    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

    btn:SetScript("OnClick", function()
        if filterPool == i then filterPool = nil else filterPool = i end
        BuildFilteredList()
        SB.LibRefresh()
    end)

    poolBtns[i] = btn
end

-- ═══════════════════════════════════════
-- Tier selector buttons
-- ═══════════════════════════════════════
local tierBtns = {}

for t = 1, 4 do
    local btn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    btn:SetSize(60, 18)
    btn:SetPoint("TOPLEFT", 30 + (t - 1) * 65, -72)
    btn:SetText("T" .. t)

    btn:SetScript("OnClick", function()
        if filterTier == t then filterTier = nil else filterTier = t end
        BuildFilteredList()
        SB.LibRefresh()
    end)

    tierBtns[t] = btn
end

-- ═══════════════════════════════════════
-- Slot filter dropdown
-- ═══════════════════════════════════════
local slotDropdown = CreateFrame("Frame", "SB_LibSlotDropdown", mainFrame, "UIDropDownMenuTemplate")
slotDropdown:SetPoint("TOPLEFT", 10, -92)
UIDropDownMenu_SetWidth(slotDropdown, 110)
UIDropDownMenu_SetText(slotDropdown, "Slot: All")

UIDropDownMenu_Initialize(slotDropdown, function(self, level)
    for _, slot in ipairs(SLOT_FILTERS) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = slot.name
        info.checked = (filterSlot == slot.mask)
        info.func = function()
            filterSlot = slot.mask
            UIDropDownMenu_SetText(slotDropdown, "Slot: " .. slot.name)
            BuildFilteredList()
            SB.LibRefresh()
        end
        UIDropDownMenu_AddButton(info)
    end
end)

-- Count
local countLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
countLabel:SetPoint("LEFT", slotDropdown, "RIGHT", -10, 2)

-- ═══════════════════════════════════════
-- Scrollable enchant list
-- ═══════════════════════════════════════
local scrollFrame = CreateFrame("ScrollFrame", "SB_LibScrollFrame", mainFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 30, -120)
scrollFrame:SetPoint("BOTTOMRIGHT", -55, 30)

local listContent = CreateFrame("Frame", nil, scrollFrame)
listContent:SetSize(1, 1)
scrollFrame:SetScrollChild(listContent)

local ROW_HEIGHT = 15
local MAX_ROWS = 40
local rows = {}

for i = 1, MAX_ROWS do
    local row = listContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    row:SetWidth(280)
    row:SetJustifyH("LEFT")
    rows[i] = row
end

-- ═══════════════════════════════════════
-- Refresh display
-- ═══════════════════════════════════════
function SB.LibRefresh()
    -- Sync status
    if SB.DB.Synced then
        syncStatus:SetText("|cff00ff00" .. #SB.DB.Enchants .. " eff.|r")
    else
        syncStatus:SetText("|cffff0000Not synced|r")
    end

    -- Pool button highlights
    for i, btn in ipairs(poolBtns) do
        if filterPool == i then
            btn.border:SetAlpha(0.8)
            btn.label:SetText(POOL_COLORS[i] .. POOL_NAMES_RU[i] .. "|r")
        else
            btn.border:SetAlpha(0)
            btn.label:SetText(POOL_NAMES_RU[i])
        end
    end

    -- Tier button highlights
    for t, btn in ipairs(tierBtns) do
        if filterTier == t then
            btn:SetText("|cffffff00T" .. t .. "|r")
        else
            btn:SetText("T" .. t)
        end
    end

    -- Count
    countLabel:SetText("|cff888888(" .. #filteredList .. ")|r")

    -- Clear rows
    for i = 1, MAX_ROWS do rows[i]:SetText("") end

    if #filteredList == 0 then
        if not SB.DB.Synced then
            rows[1]:SetText("|cffff8800Syncing...|r")
        else
            rows[1]:SetText("|cff888888No matching enchants|r")
        end
        listContent:SetHeight(ROW_HEIGHT * 2)
        return
    end

    local lastPool = nil
    local rowIdx = 0

    for _, e in ipairs(filteredList) do
        if e.pool ~= lastPool then
            lastPool = e.pool
            rowIdx = rowIdx + 1
            if rowIdx > MAX_ROWS then break end
            rows[rowIdx]:SetText(POOL_COLORS[e.pool] .. "-- " .. POOL_NAMES_RU[e.pool] .. " --|r")
        end

        rowIdx = rowIdx + 1
        if rowIdx > MAX_ROWS then break end

        local tierTag = ""
        for t = 1, 4 do
            if e.max >= TIER_RANGES[t][1] and e.min <= TIER_RANGES[t][2] then
                tierTag = tierTag .. "T" .. t .. " "
            end
        end

        local cfTag = ""
        if e.cf == 2 then cfTag = "|cffaaaaaa[W]|r "
        elseif e.cf == 4 then cfTag = "|cffaaaaaa[A]|r "
        elseif e.cf == 6 then cfTag = "|cffaaaaaa[S]|r "
        end

        rows[rowIdx]:SetText(
            POOL_COLORS[e.pool] .. "-|r " ..
            cfTag .. e.name ..
            "  |cff666666" .. tierTag .. "|r"
        )
    end

    listContent:SetHeight(rowIdx * ROW_HEIGHT + 10)
end

-- ═══════════════════════════════════════
-- Spellbook tab (reuse existing skill line tab slot)
-- ═══════════════════════════════════════
local skillLineTab = _G["SpellBookSkillLineTab" .. SKILL_LINE_TAB]

hooksecurefunc("SpellBookFrame_UpdateSkillLineTabs", function()
    skillLineTab:SetNormalTexture(TAB_ICON)
    skillLineTab.tooltip = "StatBooster Library"
    skillLineTab:Show()

    if SpellBookFrame.selectedSkillLine == SKILL_LINE_TAB then
        skillLineTab:SetChecked(true)
        mainFrame:Show()
    else
        skillLineTab:SetChecked(false)
        mainFrame:Hide()
    end
end)

hooksecurefunc("SpellBookFrame_Update", function()
    if SpellBookFrame.bookType ~= BOOKTYPE_SPELL then
        mainFrame:Hide()
    elseif SpellBookFrame.selectedSkillLine == SKILL_LINE_TAB then
        mainFrame:Show()
        -- Auto-sync if needed
        if not SB.DB.Synced then
            SendChatMessage(".sb sync", "SAY")
        end
        BuildFilteredList()
        SB.LibRefresh()
    end
end)

-- Register sync callback
local oldCallback = SB.DB.OnSyncCallback
SB.DB.OnSyncCallback = function()
    if oldCallback then oldCallback() end
    if mainFrame and mainFrame:IsShown() then
        BuildFilteredList()
        SB.LibRefresh()
    end
end

end -- InitSpellbookTab()

-- Trigger init: hook SpellBookFrame_Update which fires when spellbook opens
hooksecurefunc("SpellBookFrame_Update", function()
    if not initialized then InitSpellbookTab() end
end)

-- Public function called from StatBoosterUI slash handler
function SB.OpenLibrary()
    if not SpellBookFrame or not SpellBookFrame:IsShown() then
        ToggleSpellBook(BOOKTYPE_SPELL)
    end
    if not initialized then InitSpellbookTab() end
    if initialized then
        SpellBookFrame.selectedSkillLine = SKILL_LINE_TAB
        SpellBookFrame_Update()
        SpellBookFrame_UpdateSkillLineTabs()
    end
end
