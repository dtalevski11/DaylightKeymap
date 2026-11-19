-- DaylightKeymap
-- BindingList.lua — the Keybindings window: every bindable command, under
-- the game's own category headers, in the Daylight UI look.
--
-- Daylight UI's options pages are built from fixed row types (toggle,
-- slider, dropdown, button, text), so a plugin cannot draw a list like
-- this inside a page. The Keybindings entry in the rail opens this window
-- instead.

local ADDON, ns = ...
local API, my = ns.API, ns.my

local ROW_H, VISIBLE = 28, 16
local FILL, TEXT = ns.FILL, ns.TEXT

local win, rows, scrollOffset, listening
local expanded, searchText = {}, ""
local items = {}

local function Say(msg) print(ns.TAG .. msg) end

----------------------------------------------------------------------
-- The flattened list: a header per category, then its commands when the
-- category is open.
----------------------------------------------------------------------
local function Rebuild()
    items = {}
    local needle = searchText ~= "" and searchText:lower() or nil

    for _, group in ipairs(ns.CommandGroups()) do
        local matches = {}
        for _, entry in ipairs(group.items) do
            if not needle
                or entry.name:lower():find(needle, 1, true)
                or group.name:lower():find(needle, 1, true) then
                matches[#matches + 1] = entry
            end
        end

        if #matches > 0 then
            -- searching opens everything it found, so results are visible
            local open = needle and true or expanded[group.name]
            items[#items + 1] = { kind = "header", name = group.name,
                                  count = #matches, open = open }
            if open then
                for _, entry in ipairs(matches) do
                    items[#items + 1] = { kind = "row", entry = entry }
                end
            end
        end
    end

    local maxOffset = math.max(0, #items - VISIBLE)
    scrollOffset = math.min(scrollOffset or 0, maxOffset)
end

----------------------------------------------------------------------
-- Rebinding
----------------------------------------------------------------------
local function StopListening()
    if not listening then return end
    listening = nil
    win.capture:Hide()
    win.capture:EnableKeyboard(false)
end

local function BeginListening(command, name)
    local ok, why = ns.CanEdit()
    if not ok then Say(why); return end
    listening = { command = command, name = name }
    win.capture:Show()
    win.capture:EnableKeyboard(true)
    win.capture:SetPropagateKeyboardInput(false)
    ns.RefreshBindings()
end

----------------------------------------------------------------------
-- Rows
----------------------------------------------------------------------
local function MakeTag(parent)
    local tag = CreateFrame("Frame", nil, parent)
    tag:SetHeight(17)
    tag.bg = tag:CreateTexture(nil, "BACKGROUND")
    tag.bg:SetAllPoints()
    tag.text = API.Text(tag, "tiny")
    tag.text:SetPoint("CENTER")
    tag:Hide()

    function tag:Set(binding)
        local label = ns.PrettyBinding(binding)
        if not label then self:Hide(); return end
        self.text:SetText(label)
        self.text:SetTextColor(unpack(TEXT[1]))
        self.bg:SetColorTexture(FILL[1][1], FILL[1][2], FILL[1][3], 1)
        self:SetWidth(self.text:GetStringWidth() + 14)
        self:Show()
    end
    return tag
end

local function MakeRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H - 2)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, -(index - 1) * ROW_H)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()

    row.arrow = API.Text(row, "small", "LEFT")
    row.arrow:SetPoint("LEFT", 8, 0)

    row.name = API.Text(row, "small", "LEFT")
    row.name:SetWordWrap(false)

    row.note = API.Text(row, "tiny", "RIGHT")
    row.note:SetPoint("RIGHT", -10, 0)
    row.note:SetWordWrap(false)

    row.tag1 = MakeTag(row)
    row.tag2 = MakeTag(row)

    row.clear = CreateFrame("Button", nil, row)
    row.clear:SetSize(22, 22)
    row.clear:SetPoint("RIGHT", -6, 0)
    row.clear:SetFrameLevel(row:GetFrameLevel() + 2)
    row.clear.bg = row.clear:CreateTexture(nil, "BACKGROUND")
    row.clear.bg:SetAllPoints()
    row.clear.bg:SetColorTexture(0, 0, 0, 0)
    row.clear.mark = API.Text(row.clear, "small")
    row.clear.mark:SetPoint("CENTER")
    row.clear:Hide()

    row.clear:SetScript("OnClick", function(self)
        local item = self:GetParent().item
        if not item or item.kind ~= "row" then return end
        local a, b = ns.KeysForCommand(item.entry.command)
        if a then ns.ClearBinding(a) end
        if b then ns.ClearBinding(b) end
        ns.RefreshBindings()
        if ns.Refresh then ns.Refresh() end
    end)
    row.clear:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.45, 0.13, 0.13, 1)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Clear every key on this action", 0.94, 0.54, 0.54)
        GameTooltip:Show()
    end)
    row.clear:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0, 0, 0, 0)
        GameTooltip:Hide()
    end)

    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        local item = self.item
        if not item then return end

        if item.kind == "header" then
            expanded[item.name] = not expanded[item.name]
            ns.RefreshBindings()
            return
        end

        if button == "RightButton" then
            local a, b = ns.KeysForCommand(item.entry.command)
            if a then ns.ClearBinding(a) end
            if b then ns.ClearBinding(b) end
            ns.RefreshBindings()
            if ns.Refresh then ns.Refresh() end
        else
            BeginListening(item.entry.command, item.entry.name)
        end
    end)

    row:SetScript("OnEnter", function(self)
        local item = self.item
        if not item then return end
        if item.kind == "header" then
            self.bg:SetColorTexture(0.125, 0.145, 0.188, 1)
            return
        end
        self.bg:SetColorTexture(0.110, 0.129, 0.165, 1)
        self.clear:SetShown(item.entry and ns.KeysForCommand(item.entry.command) ~= nil)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(item.entry.name, 1, 1, 1)
        GameTooltip:AddLine("Click, then press the combo you want.", 0.6, 0.66, 0.75)
        GameTooltip:AddLine("Right-click to clear it.", 0.6, 0.66, 0.75)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        self.clear:Hide()
        ns.RefreshBindings()
    end)

    return row
end

----------------------------------------------------------------------
-- Draw
----------------------------------------------------------------------
local function RefreshScrollbar()
    local bar = win.scrollbar
    local overflow = math.max(0, #items - VISIBLE)
    bar:SetShown(overflow > 0)
    if overflow == 0 then return end

    local trackH = bar:GetHeight()
    local thumbH = math.max(26, math.floor(trackH * (VISIBLE / #items)))
    local travel = trackH - thumbH
    bar.thumb:SetHeight(thumbH)
    bar.thumb:SetPoint("TOP", bar, "TOP", 0, -math.floor(travel * (scrollOffset / overflow)))
    bar.thumb.tex:SetColorTexture(API.Accent())
    bar.thumb.tex:SetAlpha(bar.thumb.held and 1 or 0.65)
end

function ns.RefreshBindings()
    if not win or not win:IsShown() then return end
    ns.Scan()
    Rebuild()

    for i = 1, VISIBLE do
        local row = rows[i]
        local item = items[i + scrollOffset]
        row.item = item

        if not item then
            row:Hide()
        else
            row:Show()
            row.tag1:Hide()
            row.tag2:Hide()
            row.clear:Hide()

            if item.kind == "header" then
                row.bg:SetColorTexture(0.102, 0.118, 0.153, 1)
                row.arrow:SetText(item.open and "-" or "+")
                row.arrow:SetTextColor(API.Accent())
                row.name:ClearAllPoints()
                row.name:SetPoint("LEFT", row, "LEFT", 26, 0)
                row.name:SetPoint("RIGHT", row.note, "LEFT", -8, 0)
                row.name:SetText(item.name)
                row.name:SetTextColor(0.90, 0.92, 0.95)
                row.note:SetText(item.count .. (ns.IsAddonCategory(item.name) and "  addon" or ""))
                row.note:SetTextColor(0.37, 0.41, 0.47)
            else
                local entry = item.entry
                local busy = listening and listening.command == entry.command

                row.bg:SetColorTexture(busy and 0.133 or 0.071,
                                       busy and 0.110 or 0.082,
                                       busy and 0.063 or 0.106, 1)
                row.arrow:SetText("")
                row.name:SetText(entry.name)
                row.name:SetTextColor(0.847, 0.867, 0.902)

                if busy then
                    row.note:SetText("press a combo, esc to cancel")
                    row.note:SetTextColor(API.Accent())
                else
                    row.note:SetText("")
                    local a, b = ns.KeysForCommand(entry.command)
                    row.tag1:Set(a)
                    row.tag2:Set(b)
                    if row.tag1:IsShown() then
                        row.tag1:ClearAllPoints()
                        row.tag1:SetPoint("RIGHT", row, "RIGHT", -10, 0)
                    end
                    if row.tag2:IsShown() then
                        row.tag2:ClearAllPoints()
                        row.tag2:SetPoint("RIGHT", row.tag1, "LEFT", -6, 0)
                    end
                end

                -- cut the name short rather than let it run under the keys
                row.name:ClearAllPoints()
                row.name:SetPoint("LEFT", row, "LEFT", 26, 0)
                if row.tag2:IsShown() then
                    row.name:SetPoint("RIGHT", row.tag2, "LEFT", -8, 0)
                elseif row.tag1:IsShown() then
                    row.name:SetPoint("RIGHT", row.tag1, "LEFT", -8, 0)
                else
                    row.name:SetPoint("RIGHT", row.note, "LEFT", -8, 0)
                end
            end
        end
    end

    win.counter:SetText(#items .. " lines")
    win.combat:SetShown(InCombatLockdown())
    RefreshScrollbar()
end

----------------------------------------------------------------------
-- Build
----------------------------------------------------------------------
local function Build()
    win = CreateFrame("Frame", "DaylightKeymapBindings", UIParent)
    win:SetSize(760, 660)
    win:SetPoint("CENTER")
    win:SetFrameStrata("DIALOG")
    win:EnableMouse(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    API.Skin(win, { window = true })

    local handle = CreateFrame("Frame", nil, win)
    handle:SetPoint("TOPLEFT", 0, 0)
    handle:SetPoint("TOPRIGHT", -110, 0)
    handle:SetHeight(46)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function() if not InCombatLockdown() then win:StartMoving() end end)
    handle:SetScript("OnDragStop", function() win:StopMovingOrSizing() end)

    local title = API.Text(win, "title", "LEFT")
    title:SetPoint("TOPLEFT", 20, -16)
    title:SetText("Keybindings")

    local close = API.Button(win, "Close", 24)
    close:SetWidth(78)
    close:SetPoint("TOPRIGHT", -16, -14)
    close:SetScript("OnClick", function() ns.HideBindings() end)

    local search = API.Input(win, {
        search = true,
        onChange = function(text)
            searchText = text or ""
            scrollOffset = 0
            ns.RefreshBindings()
        end,
    })
    search:SetSize(320, 26)
    search:SetPoint("TOPLEFT", 20, -58)

    win.counter = API.Text(win, "tiny", "RIGHT")
    win.counter:SetPoint("RIGHT", win, "TOPRIGHT", -20, -71)
    win.counter:SetTextColor(0.37, 0.41, 0.47)

    local expandAll = API.Button(win, "Expand all", 24)
    expandAll:SetWidth(100)
    expandAll:SetPoint("TOPLEFT", search, "TOPRIGHT", 10, 0)
    expandAll:SetScript("OnClick", function()
        for _, g in ipairs(ns.CommandGroups()) do expanded[g.name] = true end
        ns.RefreshBindings()
    end)

    local collapseAll = API.Button(win, "Collapse all", 24)
    collapseAll:SetWidth(108)
    collapseAll:SetPoint("TOPLEFT", expandAll, "TOPRIGHT", 6, 0)
    collapseAll:SetScript("OnClick", function()
        wipe(expanded)
        scrollOffset = 0
        ns.RefreshBindings()
    end)

    -- the list
    local list = CreateFrame("Frame", nil, win)
    list:SetPoint("TOPLEFT", 20, -100)
    list:SetPoint("TOPRIGHT", -20, -100)
    list:SetHeight(VISIBLE * ROW_H)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        local overflow = math.max(0, #items - VISIBLE)
        scrollOffset = math.max(0, math.min(overflow, scrollOffset - delta * 3))
        ns.RefreshBindings()
    end)
    win.list = list

    rows = {}
    for i = 1, VISIBLE do rows[i] = MakeRow(list, i) end

    local sbar = CreateFrame("Frame", nil, list)
    sbar:SetWidth(6)
    sbar:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, -1)
    sbar:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 0, 1)
    sbar.bg = sbar:CreateTexture(nil, "BACKGROUND")
    sbar.bg:SetAllPoints()
    sbar.bg:SetColorTexture(0.098, 0.114, 0.145, 1)
    sbar:Hide()

    local thumb = CreateFrame("Button", nil, sbar)
    thumb:SetWidth(6)
    thumb:SetPoint("TOP", sbar, "TOP", 0, 0)
    thumb.tex = thumb:CreateTexture(nil, "ARTWORK")
    thumb.tex:SetAllPoints()
    thumb:RegisterForDrag("LeftButton")
    thumb:SetScript("OnDragStart", function(self)
        self.held = true
        self.grabY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        self.grabOffset = scrollOffset
    end)
    thumb:SetScript("OnDragStop", function(self) self.held = false; ns.RefreshBindings() end)
    thumb:SetScript("OnUpdate", function(self)
        if not self.held then return end
        local overflow = math.max(0, #items - VISIBLE)
        local travel = sbar:GetHeight() - self:GetHeight()
        if overflow == 0 or travel <= 0 then return end
        local y = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        local want = math.floor(self.grabOffset + ((self.grabY - y) / travel) * overflow + 0.5)
        want = math.max(0, math.min(overflow, want))
        if want ~= scrollOffset then scrollOffset = want; ns.RefreshBindings() end
    end)
    sbar.thumb = thumb
    win.scrollbar = sbar

    -- footer
    local note = API.Text(win, "tiny", "LEFT")
    note:SetPoint("BOTTOMLEFT", 20, 24)
    note:SetWidth(460)
    note:SetText("Click an action, then press the combo you want. Right-click clears it. Saved with the rest of your bindings.")
    note:SetTextColor(0.37, 0.41, 0.47)

    win.combat = API.Text(win, "tiny", "LEFT")
    win.combat:SetPoint("BOTTOMLEFT", 20, 8)
    win.combat:SetText("Bindings are locked in combat - the list stays readable.")
    win.combat:SetTextColor(0.75, 0.54, 0.54)
    win.combat:Hide()

    local save = API.Button(win, "Save", 26)
    save:SetWidth(100)
    save:SetPoint("BOTTOMRIGHT", -20, 16)
    save:SetScript("OnClick", function()
        if not ns.IsDirty() then Say("Nothing to save."); return end
        local ok, why = ns.Save()
        Say(ok and "Bindings saved." or why)
    end)
    if API.MainButton then API.MainButton(save, true) end

    local discard = API.Button(win, "Discard changes", 26)
    discard:SetWidth(150)
    discard:SetPoint("BOTTOMRIGHT", -130, 16)
    discard:SetScript("OnClick", function()
        if not ns.IsDirty() then Say("Nothing to discard."); return end
        ns.Discard()
        Say("Changes discarded.")
        ns.RefreshBindings()
        if ns.Refresh then ns.Refresh() end
    end)

    -- key capture
    local capture = CreateFrame("Frame", nil, win)
    capture:SetAllPoints()
    capture:SetFrameLevel(win:GetFrameLevel() + 50)
    capture:EnableKeyboard(false)
    capture:EnableMouse(true)
    capture:EnableMouseWheel(true)
    capture:Hide()

    local IGNORED = {
        LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
        LALT = true, RALT = true, UNKNOWN = true,
    }

    local function Capture(keyName)
        if not listening then return end
        if keyName == "ESCAPE" then StopListening(); ns.RefreshBindings(); return end
        if IGNORED[keyName] then return end

        local target = listening
        StopListening()

        local binding = ns.Compose(keyName, ns.CurrentLayer())
        local ok, displaced = ns.AssignBinding(binding, target.command)
        if ok then
            Say(ns.PrettyBinding(binding) .. " -> " .. target.name)
            if displaced then Say("Took it from " .. ns.CommandName(displaced) .. ".") end
        else
            Say(tostring(displaced))
        end
        ns.RefreshBindings()
        if ns.Refresh then ns.Refresh() end
    end

    capture:SetScript("OnKeyDown", function(_, keyName) Capture(keyName) end)
    -- Left and right click are how you work the window, so they never
    -- become a binding. Catching them here was how a stray click could
    -- land an action on BUTTON1 and hijack clicking entirely.
    capture:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" or button == "RightButton" then return end
        local n = button:match("^Button(%d+)$")
        if button == "MiddleButton" then n = 3 end
        if n and tonumber(n) > 2 then Capture("BUTTON" .. n) end
    end)
    capture:SetScript("OnMouseWheel", function(_, delta)
        Capture(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
    end)
    win.capture = capture

    local watch = CreateFrame("Frame")
    watch:RegisterEvent("PLAYER_REGEN_DISABLED")
    watch:RegisterEvent("PLAYER_REGEN_ENABLED")
    watch:RegisterEvent("UPDATE_BINDINGS")
    -- an addon that loads on demand can register bindings mid-session
    watch:RegisterEvent("ADDON_LOADED")
    watch:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then StopListening() end
        ns.RefreshBindings()
    end)

    pcall(my.RegisterMover, win, "bindings", "Keybindings", { "CENTER", nil, "CENTER", 0, 0 })
    win:Hide()
end

----------------------------------------------------------------------
-- Show / hide
----------------------------------------------------------------------
function ns.ShowBindings()
    if not win then Build() end
    scrollOffset = scrollOffset or 0
    win:Show()
    win:Raise()
    ns.RefreshBindings()
end

function ns.HideBindings()
    if not win then return end
    StopListening()
    if ns.IsDirty() then
        local ok, why = ns.Save()
        if not ok then Say(why .. " Your changes are still pending.") end
    end
    win:Hide()
end

function ns.ToggleBindings()
    if win and win:IsShown() then ns.HideBindings() else ns.ShowBindings() end
end

my.RegisterCommand("keybinds", function() ns.ToggleBindings() end, "Open the keybindings list")
