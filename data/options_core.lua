--=====================================================================================
-- RGX | Simple Quest Plates! - options_core.lua

-- Author: DonnieDice
-- Description: Options panel — built on RGXUI:CreateOptionsPanel
--=====================================================================================

local addonName, SQP = ...

SQP.SECTION_COLOR = {0.345, 0.745, 0.506}

function SQP:CreateOptionsPanel()
    if self.optionsPanel then
        return self.optionsPanel
    end

    local RGX = _G.RGXFramework
    local UI = RGX and RGX:GetUI() or _G.RGXUI
    if not UI then
        print("|cFFFF4444[SQP] RGXUI not available — options panel cannot be created.|r")
        return
    end

    -- SQP brand green (#58be81) on this addon's UI only. Hardcoded: core.lua
    -- also writes SQP.SECTION_COLOR ("RGX Blue") and load order decides who
    -- survives, so do not read it at runtime.
    local BrandTheme = { primary = { 0.345, 0.745, 0.506 } }
    local Design = _G.RGXDesign
    local function WithBrand(fn)
        return function(...)
            local args = { ... }
            if Design and Design.WithTheme then
                local result
                Design:WithTheme(BrandTheme, function() result = fn(unpack(args)) end)
                return result
            end
            return fn(...)
        end
    end

    local function Build()
        return UI:CreateOptionsPanel({
        addonName    = "SimpleQuestPlates",
        theme        = BrandTheme,
        title        = "|cff58be81S|cffffffffimple |cff58be81Q|cffffffffuest |cff58be81P|cfffffffflates|cff58be81!|r",
        subtitle     = "Quest tracking overlay for enemy nameplates",
        author       = SQP.AUTHOR or "DonnieDice",
        website      = "|cff7289daDiscord:|r |cffffd700discord.gg/N7kdKAHVVF|r",
        brand        = "|cff8b4b5cRGX|r |cffffd700Mods|r",
        icon         = "Interface\\AddOns\\SimpleQuestPlates\\media\\logo.tga",
        openInSettings = true,
        registerInSettings = true,
        bannerHeight = 88,
        banner       = WithBrand(function(frame)
            SQP.previewFrame = SQP:CreatePreviewSection(frame)
        end),
        tabs = {
            { text = "General", content = WithBrand(function(f) SQP:CreateGlobalOptions(f) end) },
            { text = "Kill",    content = WithBrand(function(f) SQP:CreateKillOptions(f) end),
              onSelect = function() if SQP.previewFrame then SQP.previewFrame.activateKillMode() end end },
            { text = "Loot",   content = WithBrand(function(f) SQP:CreateLootOptions(f) end),
              onSelect = function() if SQP.previewFrame then SQP.previewFrame.activateLootMode() end end },
            { text = "Percent", content = WithBrand(function(f) SQP:CreatePercentOptions(f) end),
              onSelect = function() if SQP.previewFrame then SQP.previewFrame.activatePercentMode() end end },
            { text = "About",  content = WithBrand(function(f) SQP:CreateAboutSection(f) end) },
        },
        })
    end

    if Design and Design.WithTheme then
        Design:WithTheme(BrandTheme, function() self.optionsPanel = Build() end)
    else
        self.optionsPanel = Build()
    end

    return self.optionsPanel
end

function SQP:OpenOptions()
    if InCombatLockdown() then
        self:PrintMessage(self.L["ERROR_COMBAT_LOCKDOWN"] or "Cannot open options during combat.")
        return
    end
    if not self.optionsPanel then
        self:CreateOptionsPanel()
    end
    if self.optionsPanel then self.optionsPanel:Open() end
end

StaticPopupDialogs["SQP_RESET_CONFIRM"] = {
    text = "|cff58be81Simple Quest Plates!|r\n\nAre you sure you want to reset all settings to defaults?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        SQP:ResetSettings()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
