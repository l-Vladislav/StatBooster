-- StatBoosterUI.lua — Enchant preview interface with scroll selection
local ADDON_NAME, SB = ...

local SLOT_SIZE = 37
local FRAME_WIDTH = 320
local LIST_HEIGHT = 170
local OPTION_HEIGHT = 22
local OPTION_GAP = 2

-- ═══════════════════════════════════════
-- Russian locale strings (UTF-8)
-- ═══════════════════════════════════════
local L = {}
L.title          = "\208\163\209\129\208\184\208\187\208\181\208\189\208\184\208\181 \208\191\209\128\208\181\208\180\208\188\208\181\209\130\208\176"
L.item           = "\208\159\209\128\208\181\208\180\208\188\208\181\209\130"
L.altClick       = "|cff888888Alt+\208\154\208\187\208\184\208\186 \208\191\208\190 \208\191\209\128\208\181\208\180\208\188\208\181\209\130\209\131 \208\178 \209\129\209\131\208\188\208\186\208\181 \208\184\208\187\208\184 \208\189\208\176 \208\191\208\181\209\128\209\129\208\190\208\189\208\176\208\182\208\181|r"
L.invalidItem    = "|cffff0000\208\157\208\181\208\178\208\181\209\128\208\189\209\139\208\185 \208\191\209\128\208\181\208\180\208\188\208\181\209\130|r"
L.availScrolls   = "\208\148\208\190\209\129\209\130\209\131\208\191\208\189\209\139\208\181 \209\129\208\178\208\184\209\130\208\186\208\184:"
L.rerollLabel    = "\208\159\208\181\209\128\208\181\208\177\209\128\208\190\209\129:"
L.enchants       = "\208\146\208\190\208\183\208\188\208\190\208\182\208\189\209\139\208\181 \209\131\209\129\208\184\208\187\208\181\208\189\208\184\209\143:"
L.noEnchants     = "|cff888888\208\157\208\181\209\130 \208\191\208\190\208\180\209\133\208\190\208\180\209\143\209\137\208\184\209\133 \209\131\209\129\208\184\208\187\208\181\208\189\208\184\208\185|r"
L.noReroll       = "|cffff0000\208\157\208\181\209\130 \209\131\209\129\208\184\208\187\208\181\208\189\208\184\209\143 \208\180\208\187\209\143 \208\191\208\181\209\128\208\181\208\177\209\128\208\190\209\129\208\176|r"
L.apply          = "\208\159\209\128\208\184\208\188\208\181\208\189\208\184\209\130\209\140"
L.notInBags      = "|cffff0000[StatBooster]|r \208\161\208\178\208\184\209\130\208\190\208\186 \208\189\208\181 \208\189\208\176\208\185\208\180\208\181\208\189 \208\178 \209\129\209\131\208\188\208\186\208\181"
L.clickTarget    = "|cffffff00[StatBooster]|r \208\157\208\176\208\182\208\188\208\184\209\130\208\181 \208\189\208\176 \208\191\209\128\208\181\208\180\208\188\208\181\209\130 \208\180\208\187\209\143 \208\191\209\128\208\184\208\188\208\181\208\189\208\181\208\189\208\184\209\143"
L.loaded         = "|cffffff00[StatBooster UI]|r \208\151\208\176\208\179\209\128\209\131\208\182\208\181\208\189. \208\152\209\129\208\191\208\190\208\187\209\140\208\183\209\131\208\185\209\130\208\181 |cffffff00/sb|r \208\184\208\187\208\184 \208\186\208\189\208\190\208\191\208\186\209\131 \209\131 \208\186\208\176\209\128\209\130\209\139."
L.selectScroll   = "|cff888888\208\146\209\139\208\177\208\181\209\128\208\184\209\130\208\181 \209\129\208\178\208\184\209\130\208\190\208\186|r"
L.recalibrator   = "\208\160\208\181\208\186\208\176\208\187\208\184\208\177\209\128\208\176\209\130\208\190\209\128"
L.pool           = "\208\159\209\131\208\187"
L.iLvlHigh      = "|cffff0000iLvl \208\178\209\139\209\136\208\181 92|r"
L.currentPool    = "\208\162\208\181\208\186\209\131\209\137\208\184\208\185 \208\191\209\131\208\187"

local poolNames = {
    [1] = "\208\145\208\190\208\181\208\178\208\190\208\185",
    [2] = "\208\151\208\176\209\137\208\184\209\130\208\189\209\139\208\185",
    [3] = "\208\162\208\176\208\185\208\189\209\139\208\185",
    [4] = "\208\163\208\180\208\176\209\135\208\184",
}

-- Pool → scroll item IDs per tier
local poolScrollIds = {
    [1] = { 100001, 100002, 100003, 100004 },
    [2] = { 100005, 100006, 100007, 100008 },
    [3] = { 100009, 100010, 100011, 100012 },
    [4] = { 100013, 100014, 100015, 100016 },
}

local RECALIBRATOR_ID = 41605

local tierLabels = { "T1", "T2", "T3", "T4" }

-- Fallback icons if GetItemInfo not cached
local poolDefaultIcons = {
    [1] = "Interface\\Icons\\INV_Stone_SharpeningStone_01",
    [2] = "Interface\\Icons\\INV_Misc_ArmorKit_17",
    [3] = "Interface\\Icons\\INV_Enchant_EssenceMagicLarge",
    [4] = "Interface\\Icons\\INV_Inscription_ScrollOfWisdom01",
}
local recalDefaultIcon = "Interface\\Icons\\INV_Enchant_EssenceEternalLarge"

-- ═══════════════════════════════════════
-- Helpers
-- ═══════════════════════════════════════
local function GetTierFromILvl(ilvl)
    if ilvl >= 66 then return 4
    elseif ilvl >= 46 then return 3
    elseif ilvl >= 26 then return 2
    elseif ilvl >= 1 then return 1
    else return nil end
end

local function CountItemInBags(itemId)
    local count = 0
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local id = tonumber(link:match("item:(%d+)"))
                if id == itemId then
                    local _, c = GetContainerItemInfo(bag, slot)
                    count = count + (c or 1)
                end
            end
        end
    end
    return count
end

local function FindItemInBagsById(itemId)
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local id = tonumber(link:match("item:(%d+)"))
                if id == itemId then return bag, slot, link end
            end
        end
    end
    return nil, nil, nil
end

local function GetItemIcon(itemId, fallback)
    local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(itemId)
    return texture or fallback or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- ═══════════════════════════════════════
-- Main Frame
-- ═══════════════════════════════════════
local f = CreateFrame("Frame", "StatBoosterUIFrame", UIParent, "UIPanelDialogTemplate")
f:SetSize(FRAME_WIDTH, 440)
f:SetPoint("CENTER")
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:SetClampedToScreen(true)
f:Hide()
f:SetFrameStrata("DIALOG")

f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
f.title:SetPoint("TOP", 0, -9)
f.title:SetText(L.title)

-- Small sync button (title bar, left of close button)
local syncBtn = CreateFrame("Button", nil, f)
syncBtn:SetSize(18, 18)
syncBtn:SetPoint("TOPRIGHT", -28, -6)
syncBtn:SetNormalTexture("Interface\\Icons\\Spell_Frost_Stun")
syncBtn:GetNormalTexture():SetTexCoord(0.08, 0.92, 0.08, 0.92)
syncBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
syncBtn:GetHighlightTexture():SetBlendMode("ADD")
syncBtn:SetScript("OnClick", function()
    SendChatMessage(".sb sync", "SAY")
end)
syncBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    if SB.DB.Synced then
        GameTooltip:AddLine("Sync |cff00ff00OK|r")
        GameTooltip:AddLine("|cff888888" .. #SB.DB.Enchants .. " effects|r")
    else
        GameTooltip:AddLine("Sync |cffff0000--|r")
    end
    GameTooltip:AddLine("|cffffff00Click to re-sync|r")
    GameTooltip:Show()
end)
syncBtn:SetScript("OnLeave", GameTooltip_Hide)

-- Sync status dot (next to sync button)
local syncDot = f:CreateTexture(nil, "OVERLAY")
syncDot:SetSize(8, 8)
syncDot:SetPoint("BOTTOMRIGHT", syncBtn, "BOTTOMRIGHT", -4, 4)
syncDot:SetTexture("Interface\\COMMON\\Indicator-Red")

local function UpdateSyncIndicator()
    if SB.DB.Synced then
        syncDot:SetTexture("Interface\\COMMON\\Indicator-Green")
    else
        syncDot:SetTexture("Interface\\COMMON\\Indicator-Red")
    end
end

f:SetScript("OnShow", function()
    UpdateSyncIndicator()
end)

SB.DB.OnSyncCallback = function()
    UpdateSyncIndicator()
end

tinsert(UISpecialFrames, "StatBoosterUIFrame")

-- ═══════════════════════════════════════
-- Item Slot
-- ═══════════════════════════════════════
local itemSlot = CreateFrame("Button", nil, f)
itemSlot:SetSize(SLOT_SIZE, SLOT_SIZE)
itemSlot:SetPoint("TOPLEFT", 20, -42)

itemSlot.bg = itemSlot:CreateTexture(nil, "BACKGROUND")
itemSlot.bg:SetAllPoints()
itemSlot.bg:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")

itemSlot.icon = itemSlot:CreateTexture(nil, "ARTWORK")
itemSlot.icon:SetAllPoints()
itemSlot.icon:Hide()

-- Quality color glow (square, matches slot size)
itemSlot.glow = itemSlot:CreateTexture(nil, "OVERLAY")
itemSlot.glow:SetPoint("TOPLEFT", -16, 16)
itemSlot.glow:SetPoint("BOTTOMRIGHT", 16, -16)
itemSlot.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
itemSlot.glow:SetBlendMode("ADD")
itemSlot.glow:SetAlpha(0.6)
itemSlot.glow:Hide()

itemSlot.itemLink = nil
itemSlot.itemId = nil
itemSlot.bag = nil
itemSlot.bagSlot = nil

-- Current pool icon (shown right of item slot when enchant is applied)
local poolIcon = f:CreateTexture(nil, "ARTWORK")
poolIcon:SetSize(20, 20)
poolIcon:SetPoint("LEFT", itemSlot, "RIGHT", 4, 4)
poolIcon:Hide()

-- Item name (right of pool icon, top-aligned)
local itemInfo = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
itemInfo:SetPoint("TOPLEFT", poolIcon, "TOPRIGHT", 4, 2)
itemInfo:SetWidth(FRAME_WIDTH - 100)
itemInfo:SetJustifyH("LEFT")

-- Current enchant text (below item name, shows spell + pool)
local enchantInfo = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
enchantInfo:SetPoint("TOPLEFT", itemInfo, "BOTTOMLEFT", 0, -2)
enchantInfo:SetWidth(FRAME_WIDTH - 100)
enchantInfo:SetJustifyH("LEFT")
enchantInfo:Hide()

-- Sub-info line (iLvl, tier) — below item slot
local itemSubInfo = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
itemSubInfo:SetPoint("TOPLEFT", 20, -84)
itemSubInfo:SetWidth(FRAME_WIDTH - 40)
itemSubInfo:SetJustifyH("LEFT")
itemSubInfo:SetText(L.altClick)

-- ═══════════════════════════════════════
-- Scroll Options Section
-- ═══════════════════════════════════════
local scrollHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
scrollHeader:SetPoint("TOPLEFT", 20, -100)
scrollHeader:Hide()

local scrollOptionBtns = {}
local selectedOptionIdx = nil

local function CreateScrollOption(index)
    local yOff = -118 - (index - 1) * (OPTION_HEIGHT + OPTION_GAP)
    local btn = CreateFrame("Button", nil, f)
    btn:SetSize(FRAME_WIDTH - 40, OPTION_HEIGHT)
    btn:SetPoint("TOPLEFT", 20, yOff)
    btn:Hide()

    -- Selected highlight
    btn.selectedTex = btn:CreateTexture(nil, "BACKGROUND")
    btn.selectedTex:SetAllPoints()
    btn.selectedTex:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    btn.selectedTex:SetBlendMode("ADD")
    btn.selectedTex:SetAlpha(0.4)
    btn.selectedTex:Hide()

    -- Hover highlight
    btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    btn:GetHighlightTexture():SetBlendMode("ADD")
    btn:GetHighlightTexture():SetAlpha(0.2)

    -- Icon
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(18, 18)
    btn.icon:SetPoint("LEFT", 2, 0)

    -- Name text
    btn.nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.nameText:SetPoint("LEFT", btn.icon, "RIGHT", 6, 0)
    btn.nameText:SetWidth(180)
    btn.nameText:SetJustifyH("LEFT")

    -- Count text
    btn.countText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.countText:SetPoint("RIGHT", -4, 0)

    -- State
    btn.scrollItemId = nil
    btn.pool = nil
    btn.count = 0
    btn.idx = index

    btn:SetScript("OnEnter", function(self)
        if self.scrollItemId then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. self.scrollItemId)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:SetScript("OnClick", function(self)
        SelectScrollOption(self.idx)
    end)

    scrollOptionBtns[index] = btn
    return btn
end

for i = 1, 5 do CreateScrollOption(i) end  -- 4 pools + 1 recalibrator

-- ═══════════════════════════════════════
-- Enchant list
-- ═══════════════════════════════════════
local listHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
listHeader:SetPoint("TOPLEFT", 20, -220)
listHeader:SetText(L.enchants)
listHeader:Hide()

local countLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
countLabel:SetPoint("LEFT", listHeader, "RIGHT", 8, 0)

local scrollFrame = CreateFrame("ScrollFrame", "StatBoosterUIScrollFrame", f, "UIPanelScrollFrameTemplate")

-- Reposition enchant list based on number of visible scroll option buttons
local FRAME_HEIGHT = 440
local function RepositionEnchantList(numButtons)
    local listY = -118 - numButtons * (OPTION_HEIGHT + OPTION_GAP) - 8
    local scrollY = listY - 18
    local scrollH = FRAME_HEIGHT + scrollY - 40  -- 40px reserved for apply button
    listHeader:ClearAllPoints()
    listHeader:SetPoint("TOPLEFT", 20, listY)
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", 20, scrollY)
    scrollFrame:SetSize(FRAME_WIDTH - 50, scrollH)
end
scrollFrame:SetPoint("TOPLEFT", 20, -238)
scrollFrame:SetSize(FRAME_WIDTH - 50, 170)

local listContent = CreateFrame("Frame", nil, scrollFrame)
listContent:SetSize(FRAME_WIDTH - 50, 1)
scrollFrame:SetScrollChild(listContent)

local listLines = {}
local function CreateListLine(index)
    local line = listContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line:SetPoint("TOPLEFT", 4, -(index - 1) * 14)
    line:SetWidth(FRAME_WIDTH - 60)
    line:SetJustifyH("LEFT")
    listLines[index] = line
    return line
end

-- ═══════════════════════════════════════
-- Apply button
-- ═══════════════════════════════════════
local applyBtn = CreateFrame("Button", "StatBoosterUIApplyBtn", f, "SecureActionButtonTemplate")
applyBtn:SetSize(140, 22)
applyBtn:SetPoint("BOTTOM", 0, 15)

-- Manual UIPanelButton styling (can't dual-inherit reliably in 3.3.5a)
applyBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
applyBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
applyBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
applyBtn:SetDisabledTexture("Interface\\Buttons\\UI-Panel-Button-Disabled")
applyBtn:GetNormalTexture():SetTexCoord(0, 0.625, 0, 0.6875)
applyBtn:GetPushedTexture():SetTexCoord(0, 0.625, 0, 0.6875)
applyBtn:GetHighlightTexture():SetTexCoord(0, 0.625, 0, 0.6875)
applyBtn:GetDisabledTexture():SetTexCoord(0, 0.625, 0, 0.6875)
applyBtn:SetNormalFontObject(GameFontNormal)
applyBtn:SetHighlightFontObject(GameFontHighlight)
applyBtn:SetDisabledFontObject(GameFontDisable)
applyBtn:SetText(L.apply)
applyBtn:Disable()

-- ═══════════════════════════════════════
-- Core State
-- ═══════════════════════════════════════
local currentMode = nil   -- "scroll" | "recal" | nil
local currentTier = nil
local currentILvl = nil
local currentEnchantName = nil  -- name of current SB enchant on item (for highlighting)

-- ═══════════════════════════════════════
-- Item Slot Logic
-- ═══════════════════════════════════════
local function SetItemSlot(itemLink, bag, bagSlot)
    if itemLink then
        local _, _, quality, _, _, _, _, _, _, texture = GetItemInfo(itemLink)
        itemSlot.itemLink = itemLink
        itemSlot.itemId = tonumber(itemLink:match("item:(%d+)"))
        itemSlot.bag = bag
        itemSlot.bagSlot = bagSlot
        itemSlot.icon:SetTexture(texture)
        itemSlot.icon:Show()
        itemSlot.bg:Hide()
        if quality and quality >= 2 then
            local r, g, b = GetItemQualityColor(quality)
            itemSlot.glow:SetVertexColor(r, g, b, 0.6)
            itemSlot.glow:Show()
        else
            itemSlot.glow:Hide()
        end
    else
        itemSlot.itemLink = nil
        itemSlot.itemId = nil
        itemSlot.bag = nil
        itemSlot.bagSlot = nil
        itemSlot.icon:Hide()
        itemSlot.bg:Show()
        itemSlot.glow:Hide()
    end
end

local function ClearAll()
    SetItemSlot(nil)
    selectedOptionIdx = nil
    currentMode = nil
    currentTier = nil
    currentILvl = nil
    currentEnchantName = nil
    itemInfo:SetText("")
    enchantInfo:Hide()
    itemSubInfo:SetText(L.altClick)
    poolIcon:Hide()
    scrollHeader:Hide()
    listHeader:Hide()
    countLabel:SetText("")
    applyBtn:SetAttribute("type", nil)
    applyBtn:Disable()
    for i = 1, 5 do
        scrollOptionBtns[i]:Hide()
        scrollOptionBtns[i].selectedTex:Hide()
    end
    for _, line in ipairs(listLines) do line:SetText("") end
end

-- ═══════════════════════════════════════
-- Update Scroll Options (after item placed)
-- ═══════════════════════════════════════
local function UpdateScrollOptions()
    -- Hide all options first
    for i = 1, 5 do
        scrollOptionBtns[i]:Hide()
        scrollOptionBtns[i].selectedTex:Hide()
    end
    selectedOptionIdx = nil
    currentMode = nil
    poolIcon:Hide()
    enchantInfo:Hide()
    scrollHeader:Hide()
    listHeader:Hide()
    countLabel:SetText("")
    applyBtn:SetAttribute("type", nil)
    applyBtn:Disable()
    for _, line in ipairs(listLines) do line:SetText("") end

    if not itemSlot.itemLink then return end

    local _, _, quality, ilvl, _, _, _, _, invType = GetItemInfo(itemSlot.itemLink)
    if not ilvl or not invType or invType == "" then
        itemInfo:SetText(L.invalidItem)
        return
    end

    currentILvl = ilvl

    -- Item info display
    local qualityColor = quality and select(4, GetItemQualityColor(quality)) or "|cffffffff"
    local itemName = itemSlot.itemLink:match("%[(.-)%]") or "?"
    itemInfo:SetText(qualityColor .. itemName .. "|r")

    -- Check iLvl range
    local tier = GetTierFromILvl(ilvl)
    if not tier or ilvl > 92 then
        itemSubInfo:SetText("|cff888888iLvl " .. ilvl .. "|r  " .. L.iLvlHigh)
        return
    end
    currentTier = tier

    -- Detect existing enchant
    local existingPool, enchantText = SB.DB.DetectEnchantPool(itemSlot.itemLink, itemSlot.bag, itemSlot.bagSlot)

    -- Store current enchant name for highlighting in enchant list
    currentEnchantName = enchantText

    if existingPool and existingPool ~= 0 then
        -- ── Recalibrator mode ── (existingPool > 0 = known pool, -1 = unknown pool)
        currentMode = "recal"
        local poolName = poolNames[existingPool] or "?"

        -- Show pool icon next to item
        if existingPool > 0 then
            local scrollId = poolScrollIds[existingPool] and poolScrollIds[existingPool][tier]
            if scrollId then
                poolIcon:SetTexture(GetItemIcon(scrollId, poolDefaultIcons[existingPool]))
            else
                poolIcon:SetTexture(poolDefaultIcons[existingPool] or recalDefaultIcon)
            end
            poolIcon:Show()
        else
            poolIcon:SetTexture(recalDefaultIcon)
            poolIcon:Show()
        end

        -- Show enchant spell text under item name
        if enchantText and enchantText ~= "" then
            enchantInfo:SetText("|cffffff00" .. enchantText .. "|r")
            enchantInfo:Show()
        end

        itemSubInfo:SetText("|cff888888iLvl " .. ilvl .. "  " .. tierLabels[tier] .. "|r  |cff00ff00[" .. poolName .. "]|r")
        scrollHeader:SetText(L.rerollLabel)
        scrollHeader:Show()

        local btn = scrollOptionBtns[1]
        btn.scrollItemId = RECALIBRATOR_ID
        btn.pool = 0
        btn.count = CountItemInBags(RECALIBRATOR_ID)
        btn.icon:SetTexture(GetItemIcon(RECALIBRATOR_ID, recalDefaultIcon))
        btn.nameText:SetText(L.recalibrator)
        if btn.count > 0 then
            btn.countText:SetText("|cff00ff00x" .. btn.count .. "|r")
        else
            btn.countText:SetText("|cff666666x0|r")
        end
        btn:Show()
        RepositionEnchantList(1)
        SelectScrollOption(1)
    else
        -- ── Scroll selection mode ──
        currentMode = "scroll"
        currentEnchantName = nil
        poolIcon:Hide()
        enchantInfo:Hide()
        itemSubInfo:SetText("|cff888888iLvl " .. ilvl .. "  " .. tierLabels[tier] .. "|r")
        scrollHeader:SetText(L.availScrolls)
        scrollHeader:Show()

        for i = 1, 4 do
            local btn = scrollOptionBtns[i]
            local scrollId = poolScrollIds[i][tier]
            btn.scrollItemId = scrollId
            btn.pool = i
            btn.count = CountItemInBags(scrollId)
            btn.icon:SetTexture(GetItemIcon(scrollId, poolDefaultIcons[i]))
            btn.nameText:SetText(poolNames[i] .. "  |cff888888" .. tierLabels[tier] .. "|r")
            if btn.count > 0 then
                btn.countText:SetText("|cff00ff00x" .. btn.count .. "|r")
            else
                btn.countText:SetText("|cff666666x0|r")
            end
            btn:Show()
        end
        RepositionEnchantList(4)
    end
end

-- ═══════════════════════════════════════
-- Select a scroll option → show enchant list
-- ═══════════════════════════════════════
function SelectScrollOption(idx)
    -- Deselect previous
    if selectedOptionIdx then
        scrollOptionBtns[selectedOptionIdx].selectedTex:Hide()
    end

    selectedOptionIdx = idx
    local btn = scrollOptionBtns[idx]
    btn.selectedTex:Show()

    -- Clear enchant list
    for _, line in ipairs(listLines) do line:SetText("") end
    countLabel:SetText("")
    applyBtn:SetAttribute("type", nil)
    applyBtn:Disable()
    listHeader:Show()

    if not itemSlot.itemLink or not btn.scrollItemId then return end

    local _, _, quality, ilvl, _, itemType, itemSubType, _, invType = GetItemInfo(itemSlot.itemLink)
    -- WoW 3.3.5a GetItemInfo returns type as string, not numeric classID
    -- Map to numeric: 2=Weapon, 4=Armor
    local itemClass = nil
    if itemType then
        local weaponNames = { ["Weapon"] = true, ["\208\158\209\128\209\131\208\182\208\184\208\181"] = true }
        local armorNames  = { ["Armor"] = true,  ["\208\148\208\190\209\129\208\191\208\181\209\133\208\184"] = true }
        if weaponNames[itemType] then itemClass = 2
        elseif armorNames[itemType] then itemClass = 4
        end
    end
    local itemSubClass = nil -- not needed for current filters

    if not ilvl or not invType then return end

    -- Get matching enchants using the selected scroll
    local enchants, detectedPool = SB.DB.GetMatchingEnchants(
        btn.scrollItemId, ilvl, invType, itemClass, itemSubClass,
        itemSlot.itemLink, itemSlot.bag, itemSlot.bagSlot
    )

    -- Recalibrator with no detected pool
    if btn.scrollItemId == RECALIBRATOR_ID and detectedPool == 0 then
        local line = listLines[1] or CreateListLine(1)
        line:SetText(L.noReroll)
        return
    end

    if #enchants == 0 then
        countLabel:SetText("|cffff0000(0)|r")
        local line = listLines[1] or CreateListLine(1)
        if not SB.DB.Synced then
            line:SetText("|cffff8800\208\157\208\181\209\130 \209\129\208\184\208\189\209\133\209\128\208\190\208\189\208\184\208\183\208\176\209\134\208\184\208\184 \209\129 \209\129\208\181\209\128\208\178\208\181\209\128\208\190\208\188. \208\159\208\181\209\128\208\181\208\183\208\176\208\185\208\180\208\184\209\130\208\181 \208\184\208\187\208\184 .sb sync|r") -- Нет синхронизации с сервером. Перезайдите или .sb sync
        else
            line:SetText(L.noEnchants)
        end
        return
    end

    -- Deduplicate enchant names
    local seen = {}
    local unique = {}
    for _, name in ipairs(enchants) do
        if not seen[name] then
            seen[name] = true
            table.insert(unique, name)
        end
    end

    countLabel:SetText("|cff00ff00(" .. #unique .. ")|r")

    for i, name in ipairs(unique) do
        local line = listLines[i] or CreateListLine(i)
        -- USE_SPELL enchants embed name + " — " + spell description in the
        -- tooltip text (per memory/feedback_use_spell_naming.md), so the
        -- parsed currentEnchantName may be longer than the EnchantDB name.
        -- Match either exactly or when the parsed text starts with the name.
        local isCurrent = false
        if currentEnchantName then
            if name == currentEnchantName then
                isCurrent = true
            elseif currentEnchantName:find(name, 1, true) == 1 then
                local nextChar = currentEnchantName:sub(#name + 1, #name + 1)
                if nextChar == "" or nextChar == " " then
                    isCurrent = true
                end
            end
        end
        if isCurrent then
            line:SetText("|cff00ff00" .. name .. "|r")
        else
            line:SetText("|cffffff00-|r " .. name)
        end
    end

    listContent:SetHeight(#unique * 14 + 10)

    -- Enable apply only if player has the scroll, set secure action
    if btn.count > 0 then
        local sBag, sSlot = FindItemInBagsById(btn.scrollItemId)
        if sBag then
            -- Chain: use scroll, then target the item
            local macro = "/use " .. sBag .. " " .. sSlot
            if itemSlot.bag and itemSlot.bag >= 0 and itemSlot.bagSlot then
                macro = macro .. "\n/use " .. itemSlot.bag .. " " .. itemSlot.bagSlot
            elseif itemSlot.bag == -1 and itemSlot.bagSlot then
                macro = macro .. "\n/use " .. itemSlot.bagSlot
            end
            applyBtn:SetAttribute("type", "macro")
            applyBtn:SetAttribute("macrotext", macro)
            applyBtn:Enable()
        end
    end
end

-- ═══════════════════════════════════════
-- Place item into UI
-- ═══════════════════════════════════════
local function PlaceItem(itemLink, bag, bagSlot)
    if not itemLink then return end
    local itemId = tonumber(itemLink:match("item:(%d+)"))

    -- If it's a scroll/recalibrator, ignore (don't place scrolls as items)
    if SB.DB.Scrolls[itemId] then return end

    SetItemSlot(itemLink, bag, bagSlot)
    UpdateScrollOptions()
end

-- ═══════════════════════════════════════
-- Track item pickup source via ITEM_LOCK_CHANGED
-- When a player picks up an item, the source slot gets locked and
-- this event fires with the exact (bag, slot). We record it so
-- drag-and-drop can identify the correct item instance.
-- ═══════════════════════════════════════
local lastPickupBag = nil
local lastPickupSlot = nil

local lockWatcher = CreateFrame("Frame")
lockWatcher:RegisterEvent("ITEM_LOCK_CHANGED")
lockWatcher:SetScript("OnEvent", function(self, event, bagOrSlot, slot)
    if slot then
        -- Container item: bagOrSlot = bag index, slot = slot within bag
        local _, _, locked = GetContainerItemInfo(bagOrSlot, slot)
        if locked then
            lastPickupBag = bagOrSlot
            lastPickupSlot = slot
        end
    elseif bagOrSlot then
        -- Equipment item: bagOrSlot = inventory slot ID
        if IsInventoryItemLocked(bagOrSlot) then
            lastPickupBag = -1
            lastPickupSlot = bagOrSlot
        end
    end
end)

-- ═══════════════════════════════════════
-- Item slot click handlers
-- ═══════════════════════════════════════
local function PickupFromCursor()
    local infoType, _, itemLink = GetCursorInfo()
    if infoType ~= "item" or not itemLink then return end

    -- Use the source slot recorded by ITEM_LOCK_CHANGED
    local bag = lastPickupBag
    local bagSlot = lastPickupSlot

    ClearCursor()

    -- Read the real link from the source slot (includes enchant data)
    if bag and bag >= 0 and bagSlot then
        itemLink = GetContainerItemLink(bag, bagSlot) or itemLink
    elseif bag == -1 and bagSlot then
        itemLink = GetInventoryItemLink("player", bagSlot) or itemLink
    end

    PlaceItem(itemLink, bag, bagSlot)

    lastPickupBag = nil
    lastPickupSlot = nil
end

itemSlot:SetScript("OnClick", function(self)
    if CursorHasItem() then
        PickupFromCursor()
    elseif self.itemLink then
        if IsShiftKeyDown() then
            ChatEdit_InsertLink(self.itemLink)
        else
            ClearAll()
        end
    end
end)
itemSlot:SetScript("OnReceiveDrag", function(self)
    if CursorHasItem() then
        PickupFromCursor()
    end
end)

-- Tooltip
itemSlot:SetScript("OnEnter", function(self)
    if self.itemLink then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.bag and self.bag == -1 and self.bagSlot then
            GameTooltip:SetInventoryItem("player", self.bagSlot)
        elseif self.bag and self.bag >= 0 and self.bagSlot then
            GameTooltip:SetBagItem(self.bag, self.bagSlot)
        else
            GameTooltip:SetHyperlink(self.itemLink)
        end
        GameTooltip:Show()
    end
end)
itemSlot:SetScript("OnLeave", GameTooltip_Hide)

-- ═══════════════════════════════════════
-- Apply button
-- ═══════════════════════════════════════

-- ═══════════════════════════════════════
-- Auto-refresh when item enchant changes (after apply/reroll)
-- ═══════════════════════════════════════
local refreshFrame = CreateFrame("Frame")
refreshFrame:RegisterEvent("BAG_UPDATE")
refreshFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
refreshFrame:SetScript("OnEvent", function()
    if not f:IsShown() then return end
    if not itemSlot.itemLink then return end

    -- Re-read the link from the source slot (enchant data may have changed)
    if itemSlot.bag and itemSlot.bag >= 0 and itemSlot.bagSlot then
        local newLink = GetContainerItemLink(itemSlot.bag, itemSlot.bagSlot)
        if newLink then
            itemSlot.itemLink = newLink
        end
    elseif itemSlot.bag == -1 and itemSlot.bagSlot then
        local newLink = GetInventoryItemLink("player", itemSlot.bagSlot)
        if newLink then
            itemSlot.itemLink = newLink
        end
    end

    UpdateScrollOptions()
end)

-- ═══════════════════════════════════════
-- Bag & equipment click hooks
-- ═══════════════════════════════════════
hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(self, button)
    if not f:IsShown() then return end
    if not IsAltKeyDown() then return end
    local bag = self:GetParent():GetID()
    local slot = self:GetID()
    local itemLink = GetContainerItemLink(bag, slot)
    if itemLink then
        PlaceItem(itemLink, bag, slot)
    end
end)

hooksecurefunc("PaperDollItemSlotButton_OnModifiedClick", function(self, button)
    if not f:IsShown() then return end
    if not IsAltKeyDown() then return end
    local equipSlot = self:GetID()
    local itemLink = GetInventoryItemLink("player", equipSlot)
    if itemLink then
        PlaceItem(itemLink, -1, equipSlot)
    end
end)

for i = 1, 5 do
    local bagFrame = _G["ContainerFrame" .. i]
    if bagFrame then
        for j = 1, 36 do
            local btn = _G["ContainerFrame" .. i .. "Item" .. j]
            if btn then
                btn:HookScript("OnClick", function(self, button)
                    if not f:IsShown() then return end
                    if not IsAltKeyDown() then return end
                    local bag = self:GetParent():GetID()
                    local slot = self:GetID()
                    local itemLink = GetContainerItemLink(bag, slot)
                    if itemLink then
                        PlaceItem(itemLink, bag, slot)
                    end
                end)
            end
        end
    end
end

-- ═══════════════════════════════════════
-- Slash commands
-- ═══════════════════════════════════════
SLASH_STATBOOSTERUI1 = "/statboost"
SLASH_STATBOOSTERUI2 = "/sb"
SlashCmdList["STATBOOSTERUI"] = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "debug" then
        SB.DB.DumpSyncData(0)
    elseif msg:match("^debug%s+(%d+)%s+t(%d+)$") then
        local pool, tier = msg:match("^debug%s+(%d+)%s+t(%d+)$")
        SB.DB.DumpSyncData(tonumber(pool), tonumber(tier))
    elseif msg:match("^debug%s+(%d+)$") then
        SB.DB.DumpSyncData(tonumber(msg:match("^debug%s+(%d+)$")))
    elseif msg == "sync" then
        SendChatMessage(".sb sync", "SAY")
    elseif msg == "lib" or msg == "library" then
        if SB.OpenLibrary then SB.OpenLibrary() end
        return
    else
        if f:IsShown() then f:Hide() else f:Show() end
    end
end

-- ═══════════════════════════════════════
-- Minimap button
-- ═══════════════════════════════════════
local minimapBtn = CreateFrame("Button", "StatBoosterUIMinimapButton", Minimap)
minimapBtn:SetSize(32, 32)
minimapBtn:SetFrameStrata("MEDIUM")
minimapBtn:SetFrameLevel(8)
minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
minimapBtn:SetMovable(true)

local iconOverlay = minimapBtn:CreateTexture(nil, "OVERLAY")
iconOverlay:SetSize(53, 53)
iconOverlay:SetPoint("TOPLEFT")
iconOverlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local iconBg = minimapBtn:CreateTexture(nil, "BACKGROUND")
iconBg:SetSize(20, 20)
iconBg:SetPoint("CENTER", -1, 1)
iconBg:SetTexture("Interface\\Icons\\INV_Enchant_EssenceEternalLarge")

local minimapAngle = 220
local function UpdateMinimapPosition()
    local rad = math.rad(minimapAngle)
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * 80, math.sin(rad) * 80)
end
UpdateMinimapPosition()

minimapBtn:RegisterForDrag("LeftButton")
minimapBtn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
        UpdateMinimapPosition()
    end)
end)
minimapBtn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    if StatBoosterUI_Settings then
        StatBoosterUI_Settings.minimapAngle = minimapAngle
    end
end)
minimapBtn:SetScript("OnClick", function()
    if f:IsShown() then f:Hide() else f:Show() end
end)
minimapBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("StatBooster", 1, 1, 1)
    GameTooltip:AddLine(L.title, 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
minimapBtn:SetScript("OnLeave", GameTooltip_Hide)

-- ═══════════════════════════════════════
-- Settings persistence
-- ═══════════════════════════════════════
local settingsFrame = CreateFrame("Frame")
settingsFrame:RegisterEvent("ADDON_LOADED")
settingsFrame:RegisterEvent("PLAYER_LOGOUT")
settingsFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        StatBoosterUI_Settings = StatBoosterUI_Settings or {}
        if StatBoosterUI_Settings.minimapAngle then
            minimapAngle = StatBoosterUI_Settings.minimapAngle
            UpdateMinimapPosition()
        end
    elseif event == "PLAYER_LOGOUT" then
        StatBoosterUI_Settings = StatBoosterUI_Settings or {}
        StatBoosterUI_Settings.minimapAngle = minimapAngle
    end
end)

DEFAULT_CHAT_FRAME:AddMessage(L.loaded)
