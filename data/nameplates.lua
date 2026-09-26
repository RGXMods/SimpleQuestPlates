--=====================================================================================
-- RGX | Simple Quest Plates! - nameplates.lua

-- Author: DonnieDice
-- Description: Nameplate management and tracking system
--=====================================================================================

local addonName, SQP = ...
local RGX = _G.RGXFramework

local function nowSeconds()
    if type(GetTimePreciseSec) == "function" then
        return GetTimePreciseSec()
    end
    if type(debugprofilestop) == "function" then
        return debugprofilestop() / 1000
    end
    if type(GetTime) == "function" then
        return GetTime()
    end
    return 0
end

local function reportSlowPath(label, started)
    local elapsed = nowSeconds() - started
    if elapsed < 0.050 then
        return
    end

    local now = nowSeconds()
    SQP._lastSlowPathReport = SQP._lastSlowPathReport or {}
    if (SQP._lastSlowPathReport[label] or 0) + 2 > now then
        return
    end

    SQP._lastSlowPathReport[label] = now
    local message = string.format("[SQP:slow] %s took %.1fms", tostring(label), elapsed * 1000)
    if type(_G.geterrorhandler) == "function" then
        _G.geterrorhandler()(message)
    else
        print("|cffffaa00" .. message .. "|r")
    end
end

local function normalizeFontPath(path)
    if type(path) ~= "string" or path == "" then
        return "Fonts\\FRIZQT__.TTF"
    end
    return path:gsub("/", "\\")
end

local function setFontSafe(fontString, fontPath, fontSize, fontFlags)
    if not fontString or type(fontString.SetFont) ~= "function" then
        return false
    end

    fontPath = normalizeFontPath(fontPath)
    local ok, applied = pcall(fontString.SetFont, fontString, fontPath, fontSize, fontFlags or "")
    if ok and applied ~= false then
        return true
    end

    pcall(fontString.SetFont, fontString, "Fonts\\FRIZQT__.TTF", fontSize, fontFlags or "")
    return false
end

-- Position the percent sign ("icon" mode) or the combined percent text
-- ("text" mode). In icon mode the side setting controls placement: hugging
-- the number's left/right side, or in the kill/loot mini-icon badge slots.
-- The offset sliders still apply on top (right/left modes treat X as the
-- distance from the number; badge modes mirror the kill/loot anchors).
function SQP:AnchorPercentSign(percentIcon, icon, textMode)
    if not percentIcon or not icon then
        return
    end
    local offX = SQPSettings.percentIconOffsetX or 18
    local offY = SQPSettings.percentIconOffsetY or 0
    percentIcon:ClearAllPoints()
    if textMode then
        percentIcon:SetPoint('CENTER', icon, offX, offY)
        return
    end
    local side = SQPSettings.percentSignSide or "right"
    if side == "left" then
        percentIcon:SetPoint('CENTER', icon, -offX, offY)
    else
        percentIcon:SetPoint('CENTER', icon, offX, offY)
    end
end

-- Position the kill/loot task icons relative to the main quest icon.
-- Side flips the badge between the lower-left and lower-right slots; the
-- per-type X/Y offsets fine-tune from there.
function SQP:AnchorTaskIcon(iconTex, icon, typeKey)
    if not iconTex or not icon then return end
    local x = SQPSettings[typeKey .. "IconOffsetX"]
    if x == nil then x = (typeKey == "loot") and -38 or 2 end
    local y = SQPSettings[typeKey .. "IconOffsetY"]
    if y == nil then y = (typeKey == "loot") and 16 or 15 end
    local side = SQPSettings[typeKey .. "IconSide"]
    if side == nil then side = (typeKey == "kill") and "left" or "right" end
    iconTex:ClearAllPoints()
    if side == "left" then
        iconTex:SetPoint('TOPRIGHT', icon, 'BOTTOMLEFT', x, y)
    else
        iconTex:SetPoint('TOPLEFT', icon, 'BOTTOMRIGHT', x, y)
    end
end

-- Unified mode shows the count in a native level-display style chip (dark
-- backdrop box hugging the number) instead of the floating jellybean. The
-- chip resizes to fit the current text on every update.
function SQP:UpdateUnifiedChip(questFrame)
    local chip = questFrame and questFrame.levelChip
    if not chip then
        return
    end
    local iconText = questFrame.iconText
    if not iconText or not iconText.IsShown or not iconText:IsShown() then
        chip:Hide()
        return
    end
    local text = iconText:GetText()
    if not text or text == "" then
        chip:Hide()
        return
    end
    chip:ClearAllPoints()
    chip:SetPoint("CENTER", iconText, "CENTER", 0, 0)
    local w = (iconText.GetStringWidth and iconText:GetStringWidth()) or 16
    local _, h = iconText:GetFont()
    chip:SetSize(w + 10, (h or 12) + 8)
    chip:SetColorTexture(0, 0, 0, 0.55)
    chip:Show()
end

-- Quest display glow (our texture addition — a soft accent frame around the
-- quest indicator. This never touches Blizzard's own selection highlight).
function SQP:ApplyQuestGlow(questFrame)
    local glow = questFrame and questFrame.questGlow
    if not glow then return end
    local show = (SQPSettings.showQuestGlow ~= false) and questFrame:IsShown()
    glow:SetShown(show and true or false)
end

-- Play all pulses on a plate in phase: stop them all, then start them all in
-- the same tick so the main/kill/loot animations move together.
function SQP:SyncQuestPulses(questFrame)
    if not questFrame then return end
    local pulses = { questFrame.iconPulse, questFrame.percentPulse,
        questFrame.percentOutlinePulse, questFrame.killIconPulse, questFrame.lootIconPulse }
    for _, p in ipairs(pulses) do
        if p and p.Stop then p:Stop() end
    end
    for _, p in ipairs(pulses) do
        local region = p and p.GetParent and p:GetParent()
        if p and region and region.IsShown and region:IsShown() then p:Play() end
    end
end

-- Nameplate storage
SQP.Nameplates = {} -- [plate] = frame
SQP.ActiveNameplates = {} -- [plate] = frame (visible only)
SQP.PlateGUIDs = {} -- [guid] = plate
SQP.QuestPlates = {} -- [plate] = questFrame

-- ── Unified nameplates ─────────────────────────────────────────────────────────
-- When enabled, quest overlays are parented to Blizzard's own UnitFrame and
-- anchored to its HealthBarsContainer (the technique MelloUI uses), so they
-- move, scale and fade with the native nameplate instead of floating beside
-- the plate boundary.

function SQP:IsUnifiedMode(nameplate)
    if SQPSettings.unifiedNameplates ~= true then
        return false
    end
    if not nameplate or not nameplate.UnitFrame then
        return false
    end
    if nameplate.UnitFrame.IsForbidden and nameplate.UnitFrame:IsForbidden() then
        return false
    end
    return true
end

-- The frame quest icons anchor against. Both modes prefer Blizzard's health
-- bar container so icons start flush with the bar by default (the outer
-- plate boundary moves around with cast bars and buff space, which is why
-- the old defaults never looked aligned). Older clients without those
-- internals fall back to the outer plate.
function SQP:GetPlateAnchorTarget(plate)
    local uf = plate and plate.UnitFrame
    if uf and not (uf.IsForbidden and uf:IsForbidden()) then
        if uf.HealthBarsContainer then
            return uf.HealthBarsContainer
        end
        if uf.healthBar then
            return uf.healthBar
        end
    end
    return plate
end

-- Create quest plate frame for new nameplates
function SQP:CreateQuestPlate(nameplate)
    -- Check if nameplate already has quest frame to prevent duplicates
    if self.QuestPlates[nameplate] then
        return
    end

    -- Store reference to nameplate frame
    self.Nameplates[nameplate] = nameplate

    local unified = self:IsUnifiedMode(nameplate)
    local parent = unified and nameplate.UnitFrame or nameplate

    -- Create quest overlay on the plate (or inside Blizzard's UnitFrame)
    local questFrame = CreateFrame('frame', nil, parent)
    questFrame:Hide()
    questFrame:SetAllPoints(parent)
    questFrame:EnableMouse(false)
    if unified then
        -- Draw above the health bar and its kit regions (gem caps etc.)
        local hb = nameplate.UnitFrame.HealthBarsContainer
            and nameplate.UnitFrame.HealthBarsContainer.healthBar
        local ok, level = pcall(function()
            return (hb or nameplate.UnitFrame):GetFrameLevel()
        end)
        if ok and type(level) == "number" then
            questFrame:SetFrameLevel(level + 5)
        end

        -- Level-display style chip behind the count text (the unified look:
        -- a dark backdrop hugging the number, like Blizzard's unit level).
        local chip = questFrame:CreateTexture(nil, "OVERLAY", nil, 0)
        chip:SetColorTexture(0, 0, 0, 0.55)
        chip:Hide()
        questFrame.levelChip = chip
    end
    self.QuestPlates[nameplate] = questFrame
    
    -- Quest icon (jellybean)
    local icon = questFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    icon:SetSize(28, 22)
    icon:SetTexture('Interface/QuestFrame/AutoQuest-Parts')
    icon:SetTexCoord(0.30273438, 0.41992188, 0.015625, 0.953125)
    local anchorTarget = self:GetPlateAnchorTarget(nameplate)
    icon:SetPoint(
        SQPSettings.anchor or 'RIGHT', 
        anchorTarget, 
        SQPSettings.relativeTo or 'LEFT', 
        SQPSettings.offsetX or 0,
        SQPSettings.offsetY or 0
    )
    questFrame._anchorTarget = anchorTarget
    questFrame.icon = icon

    -- Quest display glow: soft accent frame hugging the quest indicator
    -- (our texture addition; not Blizzard's selection highlight).
    local questGlow = CreateFrame("Frame", nil, questFrame, "BackdropTemplate")
    questGlow:SetPoint("TOPLEFT", icon, "TOPLEFT", -3, 3)
    questGlow:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 3, -3)
    questGlow:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    questGlow:SetBackdropBorderColor(1, 0.82, 0, 0.55)
    questGlow:EnableMouse(false)
    questGlow:Hide()
    questFrame.questGlow = questGlow

    -- Dramatic pulse for main quest icon (more noticeable)
    local function CreateMainPulse(region)
        local pulse = region:CreateAnimationGroup()
        pulse:SetLooping("REPEAT")
        local fadeOut = pulse:CreateAnimation("Alpha")
        fadeOut:SetOrder(1)
        fadeOut:SetFromAlpha(1)
        fadeOut:SetToAlpha(0.15)
        fadeOut:SetDuration(0.5)
        fadeOut:SetSmoothing("IN_OUT")
        local fadeIn = pulse:CreateAnimation("Alpha")
        fadeIn:SetOrder(2)
        fadeIn:SetFromAlpha(0.15)
        fadeIn:SetToAlpha(1)
        fadeIn:SetDuration(0.5)
        fadeIn:SetSmoothing("IN_OUT")
        pulse._fadeOut = fadeOut
        pulse._fadeIn = fadeIn
        return pulse
    end

    -- Subtle pulse for task type icons (kill/loot)
    local function CreatePulse(region)
        local pulse = region:CreateAnimationGroup()
        pulse:SetLooping("REPEAT")
        local fadeOut = pulse:CreateAnimation("Alpha")
        fadeOut:SetOrder(1)
        fadeOut:SetFromAlpha(1)
        fadeOut:SetToAlpha(0.6)
        fadeOut:SetDuration(0.6)
        fadeOut:SetSmoothing("IN_OUT")
        local fadeIn = pulse:CreateAnimation("Alpha")
        fadeIn:SetOrder(2)
        fadeIn:SetFromAlpha(0.6)
        fadeIn:SetToAlpha(1)
        fadeIn:SetDuration(0.6)
        fadeIn:SetSmoothing("IN_OUT")
        pulse._fadeOut = fadeOut
        pulse._fadeIn = fadeIn
        return pulse
    end
    
    -- Apply scale to the quest frame
    questFrame:SetScale(SQPSettings.scale or 1)
    
    -- Item texture
    local itemTexture = questFrame:CreateTexture(nil, nil, nil, 1)
    itemTexture:SetPoint('TOPRIGHT', icon, 'BOTTOMLEFT', 12, 12)
    itemTexture:SetSize(16, 16)
    itemTexture:SetMask('Interface/CharacterFrame/TempPortraitAlphaMask')
    itemTexture:Hide()
    questFrame.itemTexture = itemTexture

    -- Kill quest icon (hostile cursor knife/sword)
    local killIcon = questFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    self:AnchorTaskIcon(killIcon, icon, "kill")
    killIcon:SetSize(SQPSettings.killIconSize or 16, SQPSettings.killIconSize or 16)
    killIcon:SetTexture('Interface/Cursor/Attack')
    if not killIcon:GetTexture() then
        killIcon:SetTexture('Interface/Icons/INV_Sword_04')
        killIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    killIcon:Hide()
    questFrame.killIcon = killIcon
    questFrame.killIconPulse = CreatePulse(killIcon)

    -- Loot icon
    local lootIcon = questFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    if lootIcon.SetAtlas then
        lootIcon:SetAtlas('Banker')
    else
        lootIcon:SetTexture('Interface/Icons/INV_Misc_Bag_10')
        lootIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    lootIcon:SetSize(SQPSettings.lootIconSize or 16, SQPSettings.lootIconSize or 16)
    self:AnchorTaskIcon(lootIcon, icon, "loot")
    lootIcon:Hide()
    questFrame.lootIcon = lootIcon
    questFrame.lootIconPulse = CreatePulse(lootIcon)

    -- Quest count text
    local iconText = questFrame:CreateFontString(nil, 'OVERLAY', 'SystemFont_Outline_Small')
    if iconText.SetDrawLayer then
        iconText:SetDrawLayer('OVERLAY', 2)
    end
    iconText:SetPoint('CENTER', icon, 0.8, 0)
    iconText:SetShadowOffset(1, -1)
    iconText:SetTextColor(1, 0.82, 0)

    -- Outline text (separate layer for custom outline color)
    local iconTextOutline = questFrame:CreateFontString(nil, 'OVERLAY', 'SystemFont_Outline_Small')
    if iconTextOutline.SetDrawLayer then
        iconTextOutline:SetDrawLayer('OVERLAY', 1)
    end
    iconTextOutline:SetPoint('CENTER', icon, 0.8, 0)
    iconTextOutline:SetShadowOffset(0, 0)
    iconTextOutline:SetTextColor(0, 0, 0, 1)
    
    -- Percent icon (used for percentage quests)
    local percentIcon = questFrame:CreateFontString(nil, 'OVERLAY', 'SystemFont_Outline_Small')
    if percentIcon.SetDrawLayer then
        percentIcon:SetDrawLayer('OVERLAY', 2)
    end
    self:AnchorPercentSign(percentIcon, icon, false)
    percentIcon:SetTextColor(0.2, 1, 1)
    percentIcon:Hide()

    local percentIconOutline = questFrame:CreateFontString(nil, 'OVERLAY', 'SystemFont_Outline_Small')
    if percentIconOutline.SetDrawLayer then
        percentIconOutline:SetDrawLayer('OVERLAY', 1)
    end
    self:AnchorPercentSign(percentIconOutline, icon, false)
    percentIconOutline:SetTextColor(0, 0, 0, 1)
    percentIconOutline:Hide()

    -- Apply font settings
    self:UpdateQuestFont(iconText, iconTextOutline, percentIcon, percentIconOutline)
    
    questFrame.iconText = iconText
    questFrame.iconTextOutline = iconTextOutline
    questFrame.percentIcon = percentIcon
    questFrame.percentIconOutline = percentIconOutline
    questFrame.iconPulse = CreateMainPulse(icon)
    questFrame.percentPulse = CreatePulse(percentIcon)
    questFrame.percentOutlinePulse = CreatePulse(percentIconOutline)
    
    -- Quest complete animation (quick "pops" when the quest frame shows)
    local qmark = questFrame:CreateTexture(nil, 'OVERLAY', nil, 7)
    qmark:SetSize(SQPSettings.questMarkerSize or 28, SQPSettings.questMarkerSize or 28)
    qmark:SetPoint('CENTER', icon)
    qmark:SetTexture('Interface/WorldMap/UI-WorldMap-QuestIcon')
    qmark:SetTexCoord(0, 0.56, 0.5, 1)
    qmark:SetAlpha(0)
    questFrame.qmark = qmark
    
    local duration = 1
    local group = qmark:CreateAnimationGroup()
    local alpha = group:CreateAnimation('Alpha')
    alpha:SetOrder(1)
    alpha:SetFromAlpha(0)
    alpha:SetToAlpha(1)
    alpha:SetDuration(0)
    
    local translation = group:CreateAnimation('Translation')
    translation:SetOrder(1)
    translation:SetOffset(0, 20)
    translation:SetDuration(duration)
    translation:SetSmoothing('OUT')
    
    local alpha2 = group:CreateAnimation('Alpha')
    alpha2:SetOrder(1)
    alpha2:SetFromAlpha(1)
    alpha2:SetToAlpha(0)
    alpha2:SetDuration(duration)
    alpha2:SetSmoothing('OUT')
    
    questFrame.ani = group
    
    questFrame:HookScript('OnShow', function(self)
        if SQPSettings.showQuestMarker ~= false then
            group:Play()
        else
            qmark:SetAlpha(0)
        end
        SQP:ApplyQuestGlow(self)
        if SQPSettings.syncAnimations then
            SQP:SyncQuestPulses(self)
        end
    end)
end

-- Ensure a quest overlay exists for this plate and matches the current mode.
-- In unified mode the UnitFrame can be replaced by Blizzard on plate reuse,
-- so a cached overlay parented to a stale UnitFrame must be rebuilt.
function SQP:EnsureQuestPlate(nameplate)
    local questFrame = self.QuestPlates[nameplate]
    if questFrame and SQPSettings.unifiedNameplates then
        local expectedParent = nameplate.UnitFrame
        if expectedParent and questFrame:GetParent() ~= expectedParent then
            questFrame:Hide()
            pcall(function() questFrame:SetParent(nil) end)
            self.QuestPlates[nameplate] = nil
        end
    end
    if not self.QuestPlates[nameplate] then
        self:CreateQuestPlate(nameplate)
    end

    -- Re-anchor when Blizzard recycled the plate's internals (pool reuse,
    -- death/resurrection, style swaps): the icon may still point at a stale
    -- health bar container that no longer belongs to this plate.
    self:RefreshQuestPlateAnchor(nameplate)
end

-- Re-anchor the quest icon when its anchor target frame was replaced
function SQP:RefreshQuestPlateAnchor(nameplate)
    local questFrame = self.QuestPlates[nameplate]
    if not questFrame or not questFrame.icon then
        return
    end

    local target = self:GetPlateAnchorTarget(nameplate)
    if questFrame._anchorTarget ~= target then
        questFrame.icon:ClearAllPoints()
        questFrame.icon:SetPoint(
            SQPSettings.anchor or 'RIGHT',
            target,
            SQPSettings.relativeTo or 'LEFT',
            SQPSettings.offsetX or 0,
            SQPSettings.offsetY or 0
        )
        questFrame._anchorTarget = target
    end
end

-- Rebuild every quest overlay after switching unified/legacy mode
function SQP:RebuildQuestPlates()
    local active = {}
    for plate in pairs(self.ActiveNameplates) do
        table.insert(active, plate)
    end
    for _, questFrame in pairs(self.QuestPlates) do
        questFrame:Hide()
        pcall(function() questFrame:SetParent(nil) end)
    end
    self.QuestPlates = {}
    for _, plate in ipairs(active) do
        self:CreateQuestPlate(plate)
        self:UpdateQuestIcon(plate, plate._unitID)
    end
end

-- Nameplate show callback
function SQP:OnPlateShow(nameplate, unitID)
    local started = nowSeconds()

    -- Store unit ID on nameplate itself
    nameplate._unitID = unitID
    self.ActiveNameplates[nameplate] = nameplate

    self:EnsureQuestPlate(nameplate)
    
    local ok, guid = pcall(UnitGUID, unitID)
    if ok and guid then
        local setOk = pcall(function() self.PlateGUIDs[guid] = nameplate end)
    end

    self:UpdateQuestIcon(nameplate, unitID)

    -- Targeting a fresh plate shows Blizzard's selection highlight again
    if SQPSettings.showTargetGlow == false then
        RGX:After(0, function() self:ApplyTargetGlow(nameplate) end, "SQP target glow")
    end

    -- Recheck shortly after show to allow tooltip data to populate
    local plateRef = nameplate
    local unitRef = unitID
    local function delayedRecheck()
        if SQP.ActiveNameplates[plateRef] and plateRef._unitID == unitRef then
            SQP:UpdateQuestIcon(plateRef, unitRef)
        end
    end

    RGX:After(0.15, delayedRecheck, "SQP nameplate recheck")

    reportSlowPath("OnPlateShow", started)
end

-- Nameplate hide callback
function SQP:OnPlateHide(nameplate, unitID)
    self.ActiveNameplates[nameplate] = nil
    
    -- Only try to get GUID if we have a valid unitID
    if unitID then
        local ok, guid = pcall(UnitGUID, unitID)
        if ok and guid then
            pcall(function() self.PlateGUIDs[guid] = nil end)
        end
    end
    
    if self.QuestPlates[nameplate] then
        self.QuestPlates[nameplate]:Hide()
    end
end

-- Update font for quest text
-- typeKey: "kill", "loot", "percent", or nil (falls back to global settings)
function SQP:UpdateQuestFont(fontString, outlineFontString, percentFontString, percentOutlineFontString, typeKey)
    local started = nowSeconds()
    local S = SQPSettings or {}

    local function applyFont(main, outline, tk, sizeOverride)
        local Fonts = _G.RGXFonts
        local rgxDefaultFont = (Fonts and type(Fonts.GetDefault) == "function" and Fonts:GetDefault()) or nil
        local requestedFont = (tk and S[tk.."FontFamily"]) or S.fontFamily or rgxDefaultFont
            or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        local fontName    = requestedFont
        local fontSize    = sizeOverride or (tk and S[tk.."FontSize"]) or S.fontSize or 12
        local fontOutline = (tk and S[tk.."FontOutline"])  or S.fontOutline or ""
        local outlineWidth= (tk and S[tk.."OutlineWidth"])
        if outlineWidth == nil then outlineWidth = S.outlineWidth or 0 end
        local outlineAlpha= (tk and S[tk.."OutlineAlpha"])
        if outlineAlpha  == nil then outlineAlpha  = S.outlineAlpha  or 0 end
        local outlineColor= (tk and S[tk.."OutlineColor"]) or S.outlineColor or {0, 0, 0}

        local noOutline = fontOutline == "" or fontOutline == "NONE"
        if noOutline then outlineWidth = 0 end
        if outlineWidth < 0 then outlineWidth = 0 end

        if Fonts and type(Fonts.ResolvePath) == "function" then
            fontName = Fonts:ResolvePath(requestedFont, rgxDefaultFont or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")
        end
        fontName = normalizeFontPath(fontName)

        local mainFlag = outline and "" or (noOutline and "" or fontOutline)
        setFontSafe(main, fontName, fontSize, mainFlag)
        main:SetShadowOffset(1, -1)
        if outlineWidth <= 0 then
            main:SetShadowColor(0, 0, 0, 1)
        else
            main:SetShadowColor(0, 0, 0, 0)
        end

        if outline then
            if outlineWidth <= 0 then
                outline:Hide()
            else
                local flag = outlineWidth >= 3 and "THICKOUTLINE" or "OUTLINE"
                -- Use same fontSize as main so the border aligns correctly
                setFontSafe(outline, fontName, fontSize, flag)
                local r, g, b = unpack(outlineColor)
                outline:SetTextColor(r, g, b, outlineAlpha)
                outline:SetShadowOffset(0, 0)
                outline:SetShadowColor(0, 0, 0, 0)
                outline:Show()
            end
        end
    end

    -- Main count text uses the provided typeKey
    applyFont(fontString, outlineFontString, typeKey)

    -- Percent symbol uses percentIconSize for independent size control
    if percentFontString then
        local signSize = S.percentIconSize or nil
        applyFont(percentFontString, percentOutlineFontString, "percent", signSize)
    end

    reportSlowPath("UpdateQuestFont", started)
end

-- Refresh all nameplate positions and settings
function SQP:RefreshAllNameplates()
    -- Classic/MoP clients can rescan nameplates to ensure active list stays valid
    if self.RescanNameplates then
        self:RescanNameplates()
    end

    -- Update settings for all quest plates
    for plate, questFrame in pairs(self.QuestPlates) do
        if questFrame and questFrame.icon then
            local function IsIconStyleEnabled(typeKey)
                local value = SQPSettings[typeKey .. "ShowIconBackground"]
                if value == nil then
                    value = SQPSettings.showIconBackground
                end
                return value ~= false
            end

            questFrame.icon:ClearAllPoints()
            local refreshTarget = self:GetPlateAnchorTarget(plate)
            questFrame.icon:SetPoint(
                SQPSettings.anchor or 'RIGHT',
                refreshTarget,
                SQPSettings.relativeTo or 'LEFT',
                SQPSettings.offsetX or 0,
                SQPSettings.offsetY or 0
            )
            questFrame._anchorTarget = refreshTarget
            questFrame:SetScale(SQPSettings.scale or 1)

            if questFrame.qmark then
                local qms = SQPSettings.questMarkerSize or 28
                questFrame.qmark:SetSize(qms, qms)
            end

            if questFrame.killIcon then
                self:AnchorTaskIcon(questFrame.killIcon, questFrame.icon, "kill")
                questFrame.killIcon:SetSize(SQPSettings.killIconSize or 16, SQPSettings.killIconSize or 16)
            end
            if questFrame.lootIcon then
                self:AnchorTaskIcon(questFrame.lootIcon, questFrame.icon, "loot")
                questFrame.lootIcon:SetSize(SQPSettings.lootIconSize or 16, SQPSettings.lootIconSize or 16)
            end
            
            -- Update font settings
            if questFrame.iconText then
                local fontTypeKey
                if questFrame.hasItem then
                    fontTypeKey = "loot"
                elseif questFrame.questType == 3 then
                    fontTypeKey = "percent"
                else
                    fontTypeKey = "kill"
                end
                self:UpdateQuestFont(
                    questFrame.iconText,
                    questFrame.iconTextOutline,
                    questFrame.percentIcon,
                    questFrame.percentIconOutline,
                    fontTypeKey
                )
                
                -- Re-apply text color based on stored quest info
                if questFrame.questRelatedOnly then
                    questFrame.iconText:SetTextColor(unpack(SQPSettings.killColor or {1, 0.82, 0}))
                    if questFrame.lootIcon then
                        questFrame.lootIcon:Hide()
                    end
                    if questFrame.killIcon then
                        questFrame.killIcon:Hide()
                    end
                elseif questFrame.hasItem then
                    -- Item quest
                    questFrame.iconText:SetTextColor(unpack(SQPSettings.itemColor or {0.2, 1, 0.2}))
                    if questFrame.lootIcon then
                        if SQPSettings.showLootIcon ~= false then
                            questFrame.lootIcon:Show()
                        else
                            questFrame.lootIcon:Hide()
                        end
                    end
                    if questFrame.killIcon then
                        questFrame.killIcon:Hide()
                    end
                elseif questFrame.questType then
                    if questFrame.questType == 1 then
                        -- Kill quest
                        questFrame.iconText:SetTextColor(unpack(SQPSettings.killColor or {1, 0.82, 0}))
                        if questFrame.lootIcon then
                            questFrame.lootIcon:Hide()
                        end
                        if questFrame.killIcon then
                            if SQPSettings.showKillIcon ~= false then
                                questFrame.killIcon:Show()
                            else
                                questFrame.killIcon:Hide()
                            end
                        end
                    elseif questFrame.questType == 2 then
                        -- Completed quest
                        questFrame.iconText:SetTextColor(1, 1, 1)
                        if questFrame.lootIcon then
                            questFrame.lootIcon:Hide()
                        end
                        if questFrame.killIcon then
                            questFrame.killIcon:Hide()
                        end
                    elseif questFrame.questType == 3 then
                        -- Progress quest
                        questFrame.iconText:SetTextColor(unpack(SQPSettings.percentColor or {0.2, 1, 1}))
                        if questFrame.lootIcon then
                            questFrame.lootIcon:Hide()
                        end
                        if questFrame.killIcon then
                            questFrame.killIcon:Hide()
                        end
                    end
                end
            end

            if questFrame.percentIcon then
                if questFrame.questType == 3 then
                    local percentIconMode = IsIconStyleEnabled("percent")
                    self:AnchorPercentSign(questFrame.percentIcon, questFrame.icon, not percentIconMode)
                    if SQPSettings.percentTintIcon and SQPSettings.percentTintIconColor then
                        local r, g, b, a = unpack(SQPSettings.percentTintIconColor)
                        questFrame.percentIcon:SetTextColor(r, g, b, a or 1)
                    else
                        questFrame.percentIcon:SetTextColor(unpack(SQPSettings.percentColor or {0.2, 1, 1}))
                    end
                    questFrame.percentIcon:Show()
                    if questFrame.percentIconOutline then
                        self:AnchorPercentSign(questFrame.percentIconOutline, questFrame.icon, not percentIconMode)
                        local outlineWidth = SQP:GetOutlineInfo("percent")
                        if outlineWidth and outlineWidth > 0 then
                            questFrame.percentIconOutline:Show()
                        else
                            questFrame.percentIconOutline:Hide()
                        end
                    end
                    if questFrame.icon then
                        if percentIconMode then
                            questFrame.icon:Show()
                        else
                            questFrame.icon:Hide()
                        end
                    end
                else
                    local nonPercentType = questFrame.hasItem and "loot" or "kill"
                    local nonPercentIconMode = IsIconStyleEnabled(nonPercentType)
                    questFrame.percentIcon:Hide()
                    if questFrame.percentIconOutline then
                        questFrame.percentIconOutline:Hide()
                    end
                    if questFrame.icon then
                        if nonPercentIconMode then
                            questFrame.icon:Show()
                        else
                            questFrame.icon:Hide()
                        end
                    end
                end
            end
            
            -- Main icon tinting removed (redundant with color controls)
            questFrame.icon:SetVertexColor(1, 1, 1, 1)

            local killTintEnabled = SQPSettings.killTintIcon and SQPSettings.killTintIconColor
            local killTintR, killTintG, killTintB, killTintA = 1, 1, 1, 1
            if killTintEnabled then
                killTintR, killTintG, killTintB, killTintA = unpack(SQPSettings.killTintIconColor)
            end
            local lootTintEnabled = SQPSettings.lootTintIcon and SQPSettings.lootTintIconColor
            local lootTintR, lootTintG, lootTintB, lootTintA = 1, 1, 1, 1
            if lootTintEnabled then
                lootTintR, lootTintG, lootTintB, lootTintA = unpack(SQPSettings.lootTintIconColor)
            end
            local percentTintEnabled = SQPSettings.percentTintIcon and SQPSettings.percentTintIconColor
            local percentTintR, percentTintG, percentTintB, percentTintA = 1, 1, 1, 1
            if percentTintEnabled then
                percentTintR, percentTintG, percentTintB, percentTintA = unpack(SQPSettings.percentTintIconColor)
            end

            if questFrame.killIcon then
                if killTintEnabled then
                    questFrame.killIcon:SetVertexColor(killTintR, killTintG, killTintB, killTintA)
                else
                    questFrame.killIcon:SetVertexColor(1, 1, 1, 1)
                end
            end
            if questFrame.lootIcon then
                if lootTintEnabled then
                    questFrame.lootIcon:SetVertexColor(lootTintR, lootTintG, lootTintB, lootTintA)
                else
                    questFrame.lootIcon:SetVertexColor(1, 1, 1, 1)
                end
            end
            if questFrame.percentIcon and questFrame.questType == 3 then
                if percentTintEnabled then
                    questFrame.percentIcon:SetTextColor(percentTintR, percentTintG, percentTintB, percentTintA or 1)
                else
                    questFrame.percentIcon:SetTextColor(unpack(SQPSettings.percentColor or {0.2, 1, 1}))
                end
            end
        end
    end
    
    -- Force update quest display
    for plate in pairs(self.ActiveNameplates) do
        self:UpdateQuestIcon(plate, plate._unitID)
    end
end
