--=====================================================================================
-- RGX | Simple Quest Plates! - options_general.lua

-- Author: DonnieDice
-- Description: Global settings tab (addon state, combat, position, scale)
--=====================================================================================

local addonName, SQP = ...
local format = string.format

function SQP:RefreshOptionsPreview(activatePreviewFn)
    if type(activatePreviewFn) == "function" then
        activatePreviewFn()
    end

    if self.previewFrame and type(self.previewFrame.UpdatePreview) == "function" then
        self.previewFrame:UpdatePreview()
    end
end

function SQP:RefreshFontDisplays(activatePreviewFn)
    if type(activatePreviewFn) == "function" then
        activatePreviewFn()
    end

    if self.previewFrame and type(self.previewFrame.UpdatePreview) == "function" then
        self.previewFrame:UpdatePreview()
    end

    if type(self.RefreshAllNameplates) == "function" then
        self:RefreshAllNameplates()
    end
end

function SQP:CreateGlobalOptions(content)
    if not self.optionControls then self.optionControls = {} end
    local rgxFonts = _G.RGXFonts


    local leftColumn, rightColumn = SQP:CreateOptionColumns(content)

    -- â”€â”€ LEFT COLUMN: Addon state + toggles + combat â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    local yOffset = -12

    -- Addon State (module-page style switch, shared framework control)
    local addonStateLabel = leftColumn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    addonStateLabel:SetPoint("TOPLEFT", 20, yOffset)
    addonStateLabel:SetText("|cff58be81" .. (self.L["OPTIONS_ADDON_STATE"] or "Addon State") .. "|r")
    SQP:ApplyDefaultFont(addonStateLabel)
    yOffset = yOffset - 20

    local UI = _G.RGXUI
    if UI and type(UI.CreateSwitch) == "function" then
        local addonSwitch = UI:CreateSwitch(leftColumn, {
            label    = "",
            key      = "enabled",
            storage  = SQPSettings,
            default  = true,
            onChange = function(enabled)
                SQP:SetSetting('enabled', enabled)
                SQP:RefreshAllNameplates()
            end,
        })
        addonSwitch:SetWidth(200)
        addonSwitch:SetPoint("TOPLEFT", 20, yOffset)
        self.optionControls.addonStateSwitch = addonSwitch
        yOffset = yOffset - 26
    end

    local enableButton  = self:CreateStyledButton(leftColumn, self.L["OPTIONS_ENABLE"]  or "Enable",  68, 20)
    local disableButton = self:CreateStyledButton(leftColumn, self.L["OPTIONS_DISABLE"] or "Disable", 68, 20)
    enableButton:SetPoint("TOPLEFT", 20, yOffset)
    disableButton:SetPoint("LEFT", enableButton, "RIGHT", 10, 0)

    local function UpdateEnabledButtons()
        if SQPSettings.enabled ~= false then
            enableButton:SetAlpha(1); disableButton:SetAlpha(0.6)
        else
            enableButton:SetAlpha(0.6); disableButton:SetAlpha(1)
        end
    end
    UpdateEnabledButtons()
    self.optionControls.updateEnabledButtons = UpdateEnabledButtons

    enableButton:SetScript("OnClick", function()
        SQP:SetSetting('enabled', true); UpdateEnabledButtons(); SQP:RefreshAllNameplates()
    end)
    disableButton:SetScript("OnClick", function()
        SQP:SetSetting('enabled', false); UpdateEnabledButtons(); SQP:RefreshAllNameplates()
    end)
    -- Hide the fallback row when the framework switch rendered above
    if UI and type(UI.CreateSwitch) == "function" then
        enableButton:Hide(); disableButton:Hide()
    end
    yOffset = yOffset - 24

    -- General Settings
    local generalSection = leftColumn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    SQP:ApplyDefaultFont(generalSection)
    generalSection:SetPoint("TOPLEFT", 20, yOffset)
    generalSection:SetText("|cff58be81" .. (self.L["OPTIONS_GENERAL"] or "General Settings") .. "|r")
    yOffset = yOffset - 14

    local debugFrame = self:CreateStyledCheckbox(leftColumn, self.L["OPTIONS_DEBUG"] or "Enable Debug Mode")
    debugFrame:SetPoint("TOPLEFT", 20, yOffset)
    debugFrame.checkbox:SetChecked(SQPSettings.debug)
    self.optionControls.debug = debugFrame.checkbox
    debugFrame.checkbox:SetScript("OnClick", function(self)
        SQP:SetSetting('debug', self:GetChecked())
        SQP:PrintMessage(SQPSettings.debug and "Debug mode enabled" or "Debug mode disabled")
    end)
    yOffset = yOffset - 18

    local chatFrame = self:CreateStyledCheckbox(leftColumn, self.L["OPTIONS_CHAT_MESSAGES"] or "Show Chat Messages")
    chatFrame:SetPoint("TOPLEFT", 20, yOffset)
    chatFrame.checkbox:SetChecked(SQPSettings.showMessages ~= false)
    self.optionControls.showMessages = chatFrame.checkbox
    chatFrame.checkbox:SetScript("OnClick", function(self)
        SQP:SetSetting('showMessages', self:GetChecked())
    end)
    yOffset = yOffset - 20

    -- Quest Display: background texture selector (framework dropdown)
    local unifyHeader = leftColumn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    unifyHeader:SetPoint("TOPLEFT", 20, yOffset)
    unifyHeader:SetText("|cff58be81Quest Display|r")
    SQP:ApplyDefaultFont(unifyHeader)
    yOffset = yOffset - 16

    local Drops = _G.RGXDropdowns
    if Drops and type(Drops.CreateNestedDropdown) == "function" then
        local dd = Drops:CreateNestedDropdown(leftColumn, {
            label = "Background style",
            width = 220,
            value = (SQPSettings.unifiedNameplates == true),
            items = {
                { text = "Floating icon (default)", value = false },
                { text = "Level chip (native)",     value = true  },
            },
            onChange = function(value)
                SQP:SetSetting('unifiedNameplates', value == true)
                SQP:RebuildQuestPlates()
                if SQP.previewFrame and type(SQP.previewFrame.UpdatePreview) == "function" then
                    SQP.previewFrame:UpdatePreview()
                end
            end,
        })
        SQP:SetControlTooltip(dd, "Pick the quest display background. Level chip renders the count in a native level-style backdrop on the nameplate.")
        self.optionControls.unifiedDropdown = dd
    end
    yOffset = yOffset - 30


    local syncFrame = self:CreateStyledCheckbox(leftColumn, "Sync icon animations")
    syncFrame:SetPoint("TOPLEFT", 20, yOffset)
    syncFrame.checkbox:SetChecked(SQPSettings.syncAnimations == true)
    self.optionControls.syncAnimations = syncFrame.checkbox
    syncFrame.checkbox:SetScript("OnClick", function(self)
        SQP:SetSetting('syncAnimations', self:GetChecked())
        SQP:RefreshAllNameplates()
    end)
    SQP:SetControlTooltip(syncFrame, "Play the main, kill, loot and percent pulses in phase.")
    yOffset = yOffset - 20

    local minimapSection = leftColumn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    SQP:ApplyDefaultFont(minimapSection)
    minimapSection:SetPoint("TOPLEFT", 20, yOffset)
    minimapSection:SetText("|cff58be81Minimap Icon|r")
    yOffset = yOffset - 14

    local minimapFrame = self:CreateStyledCheckbox(leftColumn, "Show minimap icon")
    minimapFrame:SetPoint("TOPLEFT", 20, yOffset)
    minimapFrame.checkbox:SetChecked(SQPSettings.minimapIconEnabled ~= false)
    self.optionControls.minimapIconEnabled = minimapFrame.checkbox
    minimapFrame.checkbox:SetScript("OnClick", function(self)
        SQP:ToggleMinimapIcon(self:GetChecked())
    end)
    SQP:SetControlTooltip(minimapFrame, "Left-click opens options. Drag to move. Ctrl-right-click hides it.")
    yOffset = yOffset - 24

    -- Global Animation Override
    -- Combat Settings
    local combatSection = leftColumn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    SQP:ApplyDefaultFont(combatSection)
    combatSection:SetPoint("TOPLEFT", 20, yOffset)
    combatSection:SetText("|cff58be81" .. (self.L["OPTIONS_COMBAT"] or "Combat Settings") .. "|r")
    yOffset = yOffset - 14

    local combatFrame = self:CreateStyledCheckbox(leftColumn, self.L["OPTIONS_HIDE_COMBAT"] or "Hide Icons in Combat")
    combatFrame:SetPoint("TOPLEFT", 20, yOffset)
    combatFrame.checkbox:SetChecked(SQPSettings.hideInCombat)
    self.optionControls.hideInCombat = combatFrame.checkbox
    combatFrame.checkbox:SetScript("OnClick", function(self)
        SQP:SetSetting('hideInCombat', self:GetChecked()); SQP:RefreshAllNameplates()
    end)
    yOffset = yOffset - 18

    local instanceFrame = self:CreateStyledCheckbox(leftColumn, self.L["OPTIONS_HIDE_INSTANCE"] or "Hide Icons in Instances")
    instanceFrame:SetPoint("TOPLEFT", 20, yOffset)
    instanceFrame.checkbox:SetChecked(SQPSettings.hideInInstance)
    self.optionControls.hideInInstance = instanceFrame.checkbox
    instanceFrame.checkbox:SetScript("OnClick", function(self)
        SQP:SetSetting('hideInInstance', self:GetChecked()); SQP:RefreshAllNameplates()
    end)
    yOffset = yOffset - 26

    local testButton = self:CreateStyledButton(leftColumn, self.L["OPTIONS_TEST"] or "Test Detection", 120, 20)
    testButton:SetPoint("TOPLEFT", 20, yOffset)
    testButton:SetScript("OnClick", function() SQP:TestQuestDetection() end)

    local resetButton = self:CreateStyledButton(leftColumn, self.L["OPTIONS_RESET"] or "Reset All Settings", 138, 20)
    resetButton:SetPoint("LEFT", testButton, "RIGHT", 8, 0)
    resetButton:SetAlpha(0.8)
    resetButton:SetScript("OnClick", function() StaticPopup_Show("SQP_RESET_CONFIRM") end)

    -- â”€â”€ RIGHT COLUMN: Position & Scale â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    local rightYOffset = -12

    local posScaleLabel = rightColumn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    SQP:ApplyDefaultFont(posScaleLabel)
    posScaleLabel:SetPoint("TOPLEFT", 20, rightYOffset)
    posScaleLabel:SetText("|cff58be81Position & Scale|r")
    rightYOffset = rightYOffset - 14

	-- Global Scale
	local scaleSlider = self:CreateStyledSlider(rightColumn, {
		key = "scale",
		label = "Scale",
		min = 0.5,
		max = 3.0,
		step = 0.1,
		default = 1.1,
		storage = SQPSettings,
		suffix = "",
		width = 160,
		onChange = function(value)
			SQP:RefreshAllNameplates()
		end,
	})
	scaleSlider:SetPoint("TOPLEFT", 20, rightYOffset)
	self.optionControls.scale = scaleSlider
	self.optionControls.scaleLabel = scaleSlider.valueLabel

	rightYOffset = rightYOffset - 42

	-- X Offset
	local xSlider = self:CreateStyledSlider(rightColumn, {
		key = "offsetX",
		label = "Offset X",
		min = -100,
		max = 100,
		step = 1,
		default = 0,
		storage = SQPSettings,
		width = 160,
		onChange = function(value)
			SQP:RefreshAllNameplates()
		end,
	})
	xSlider:SetPoint("TOPLEFT", 20, rightYOffset)
	self.optionControls.offsetX = xSlider
	self.optionControls.offsetXLabel = xSlider.valueLabel

	rightYOffset = rightYOffset - 42

	-- Y Offset
	local ySlider = self:CreateStyledSlider(rightColumn, {
		key = "offsetY",
		label = "Offset Y",
		min = -100,
		max = 100,
		step = 1,
		default = 0,
		storage = SQPSettings,
		width = 160,
		onChange = function(value)
			SQP:RefreshAllNameplates()
		end,
	})
	ySlider:SetPoint("TOPLEFT", 20, rightYOffset)
	self.optionControls.offsetY = ySlider
	self.optionControls.offsetYLabel = ySlider.valueLabel

	rightYOffset = rightYOffset - 42

    -- Nameplate Side
    local anchorLabel = rightColumn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    SQP:ApplyDefaultFont(anchorLabel)
    anchorLabel:SetPoint("TOPLEFT", 20, rightYOffset)
    anchorLabel:SetText("Nameplate Side")
    rightYOffset = rightYOffset - 18

    local leftBtn  = self:CreateStyledButton(rightColumn, "Left Side",  84, 20)
    local rightBtn = self:CreateStyledButton(rightColumn, "Right Side", 84, 20)
    leftBtn:SetPoint("TOPLEFT", 20, rightYOffset)
    rightBtn:SetPoint("LEFT", leftBtn, "RIGHT", 8, 0)
    self.optionControls.anchorButtons = {left = leftBtn, right = rightBtn}

    local function UpdateAnchorButtons()
        leftBtn:SetAlpha( SQPSettings.anchor == "RIGHT" and 1 or 0.6)
        rightBtn:SetAlpha(SQPSettings.anchor == "LEFT"  and 1 or 0.6)
    end
    self.optionControls.updateAnchorButtons = UpdateAnchorButtons
    UpdateAnchorButtons()

    leftBtn:SetScript("OnClick", function()
        SQP:SetSetting('anchor', "RIGHT")
        SQP:SetSetting('relativeTo', "LEFT")
        UpdateAnchorButtons()
        SQP:RefreshAllNameplates()
    end)
    rightBtn:SetScript("OnClick", function()
        SQP:SetSetting('anchor', "LEFT")
        SQP:SetSetting('relativeTo', "RIGHT")
        UpdateAnchorButtons()
        SQP:RefreshAllNameplates()
    end)

    local anchorReset = self:CreateInlineResetButton(rightColumn, function()
        SQP:SetSetting('anchor', "RIGHT")
        SQP:SetSetting('relativeTo', "LEFT")
        UpdateAnchorButtons()
        SQP:RefreshAllNameplates()
    end)
    anchorReset:SetPoint("LEFT", rightBtn, "RIGHT", 6, 0)

    rightYOffset = rightYOffset - 30
    rightYOffset = self:CreateFontSection(rightColumn, nil, nil, rightYOffset)
end
