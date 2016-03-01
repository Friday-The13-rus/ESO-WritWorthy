local LAM2 = LibStub("LibAddonMenu-2.0")

local GuildGoldDeposits = {}
GuildGoldDeposits.name = "GuildGoldDeposits"
GuildGoldDeposits.version = 1
GuildGoldDeposits.default = {
      enable_guild  = { true, true, true, true, true }
    , duration_days = 7
}
GuildGoldDeposits.max_guild_ct = 5

-- Init ----------------------------------------------------------------------

function GuildGoldDeposits.OnAddOnLoaded(event, addonName)
    if addonName ~= GuildGoldDeposits.name then return end
    if not GuildGoldDeposits.version then return end
    if not GuildGoldDeposits.default then return end
    GuildGoldDeposits:Initialize()
end

function GuildGoldDeposits:Initialize()
    self.savedVariables = ZO_SavedVars:New(
                              "GuildGoldDepositsVars"
                            , self.version
                            , nil
                            , self.default
                            )
    self:CreateSettingsWindow()
    EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_ADD_ON_LOADED)
end

-- UI ------------------------------------------------------------------------

function GuildGoldDeposits.ref_cb(i)
    return "GuildGoldDeposits_cbg" .. i
end

function GuildGoldDeposits.ref_desc(i)
    return "GuildGoldDeposits_desc" .. i
end

function GuildGoldDeposits:CreateSettingsWindow()
    local panelData = {
        type                = "panel",
        name                = "Guild Gold Deposits",
        displayName         = "Guild Gold Deposits",
        author              = "ziggr",
        version             = self.version,
        slashCommand        = "/gg",
        registerForRefresh  = true,
        registerForDefaults = false,
    }
    local cntrlOptionsPanel = LAM2:RegisterAddonPanel( self.name
                                                     , panelData
                                                     )
    local optionsData = {
        { type      = "button"
        , name      = "Save Data Now"
        , tooltip   = "Save guild gold deposit data to file now."
        , func      = function() self:SaveNow() end
        },
        { type      = "header"
        , name      = "Duration"
        },
        { type      = "slider"
        , name      = "Days to save"
        , tooltip   = "How many days' data to save?"
        , min       = 1
        , max       = 21
        , step      = 1
        , getFunc   = function() return self.savedVariables.duration_days end
        , setFunc   = function(value) self.savedVariables.duration_days = value end
        },
        { type      = "header"
        , name      = "Guilds"
        },
    }

    for i = 1, self.max_guild_ct do
        table.insert(optionsData,
            { type      = "checkbox"
            , name      = "(guild " .. i .. ")"
            , tooltip   = "Save data for guild " .. i .. "?"
            , getFunc   = function() return self.savedVariables.enable_guild[i] end
            , setFunc   = function(e) self.savedVariables.enable_guild[i] = e end
            , reference = self.ref_cb(i)
            })

                        -- HACK: for some reason, I cannot get "description"
                        -- items to dynamically update their text. Color and
                        -- hidden, yes, but text? Nope, it never changes. So
                        -- instead of a desc for static text, I'm going to use
                        -- a "checkbox" with the on/off field hidden. Total
                        -- hack. Sorry.
        table.insert(optionsData,
            { type      = "checkbox"
            , name      = "(desc " .. i .. ")"
            , reference = self.ref_desc(i)
            , getFunc   = function() return false end
            , setFunc   = function() end
            })
    end

    LAM2:RegisterOptionControls("GuildGoldDeposits", optionsData)
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated"
            , self.OnPanelControlsCreated)
end

-- Delayed initialization of options panel: don't waste time fetching
-- guild names until a human actually opens our panel.
function GuildGoldDeposits.OnPanelControlsCreated(panel)
    self = GuildGoldDeposits
    guild_ct = GetNumGuilds()
    for i = 1,self.max_guild_ct do
        cb = _G[self.ref_cb(i)]
        if i <= guild_ct then
            guildId   = GetGuildId(i)
            guildName = GetGuildName(guildId)
            cb.label:SetText(guildName)
            cb:SetHidden(false)
        else
                        -- If no guild #N, hide and disable it.
            cb:SetHidden(true)
            self.savedVariables.enable_guild[i] = false
        end

        desc = _G[self.ref_desc(i)]
        self.ConvertCheckboxToText(desc)
    end
end

-- Coerce a checkbox to act like a text label.
--
-- I cannot get LibAddonMenu-2.0 "description" items to dynamically update
-- their text. SetText() has no effect. But SetText() works on "checkbox"
-- items, so beat those into a text-like UI element.
function GuildGoldDeposits.ConvertCheckboxToText(cb)
    desc:SetHandler("OnMouseEnter", nil)
    desc:SetHandler("OnMouseExit",  nil)
    desc:SetHandler("OnMouseUp",    nil)
    desc.label:SetFont("ZoFontGame")
    desc.label:SetText("-")
    desc.checkbox:SetHidden(true)
end

-- Saving Guild Data ---------------------------------------------------------

function GuildGoldDeposits:SaveNow()
    -- self:DumpSettings()
    for i = 1, self.max_guild_ct do
        self:SaveGuildIndex(i)
    end
end

function GuildGoldDeposits:SaveGuildIndex(i)
    guildId = GetGuildId(i)
    desc = _G[GuildGoldDeposits.ref_desc(i)].label
    if self.savedVariables.enable_guild[i] then
        color = ZO_DEFAULT_ENABLED_COLOR
        text  = "gonna do something"
    else
        color = ZO_DEFAULT_DISABLED_COLOR
        text  = "not doing nothing"
    end
    desc:SetText(text)
end

function GuildGoldDeposits:DumpSettings()
    d("sv.days " .. self.savedVariables.duration_days)
    for i = 1, self.max_guild_ct do
        d("sv.eg[" .. i .. "] = "
          .. tostring(self.savedVariables.enable_guild[i]))
    end
end

-- GetGuildEventInfo(3, GUILD_HISTORY_BANK_DEPOSITS, 2)
-- 21 1656 @J-man8898 5000 nil nil nil nil
-- 2016-02-29 14:45:37 -0700 ziggr: "@J-man8898 deposited 5,000g 27 minutes ago
-- 21 1741 @J-man8898 5000 nil nil nil nil
-- 2016-02-29 14:46:44 -0700 ziggr:  "@J-man8898 deposited 5,000g 27 minutes ago
-- So field 2 is RELATIVE TIME AGO and likeluy SECONDS ago

-- GetGuildEventInfo(3, GUILD_HISTORY_BANK_DEPOSITS, 2)
-- 0/nil at first, until I opened the Guild history.
-- So there must be an open/init sequence.

-- GetTimeStamp() returns seconds since the epoch. That, minus above, is
-- seconds-since-the-epoch of the item/event.





-- Postamble -----------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent( GuildGoldDeposits.name
                              , EVENT_ADD_ON_LOADED
                              , GuildGoldDeposits.OnAddOnLoaded
                              )
