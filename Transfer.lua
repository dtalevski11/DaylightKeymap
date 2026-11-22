-- DaylightKeymap
-- Transfer.lua — export and import bindings as text.
--
-- An addon cannot write a file, so the exchange is a box you copy out of or
-- paste into. The format is deliberately plain: one binding per line, so a
-- person can read it, edit it in a text file, and see what went wrong when
-- something does.

local ADDON, ns = ...
local API, my = ns.API, ns.my

local HEADER = "KEYMAP1"
local win

local function Say(msg) print(ns.TAG .. msg) end

----------------------------------------------------------------------
-- Text in, text out
----------------------------------------------------------------------
function ns.ExportString()
    local out = { HEADER }
    local seen = {}

    for i = 1, GetNumBindings() do
        local command = GetBinding(i)
        if type(command) == "string" and command ~= ""
            and not command:find("^HEADER_") then
            local a, b = GetBindingKey(command)
            if a and not seen[a] then seen[a] = true; out[#out + 1] = a .. "=" .. command end
            if b and not seen[b] then seen[b] = true; out[#out + 1] = b .. "=" .. command end
        end
    end

    return table.concat(out, "\n"), #out - 1
end

-- Returns a list of { binding, command }, or nil and a reason.
function ns.ParseImport(text)
    if type(text) ~= "string" or text == "" then
        return nil, "Nothing pasted."
    end

    local lines, pairsOut = {}, {}
    for line in text:gmatch("[^\r\n]+") do lines[#lines + 1] = line end

    local first = lines[1] and lines[1]:gsub("%s", "") or ""
    if first ~= HEADER then
        return nil, "That does not look like a Keymap export. The first line should read " .. HEADER .. "."
    end

    for i = 2, #lines do
        local line = lines[i]:gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" then
            local binding, command = line:match("^(.-)=(.+)$")
            if binding and command and binding ~= "" and command ~= "" then
                pairsOut[#pairsOut + 1] = { binding = binding, command = command }
            end
        end
    end

    if #pairsOut == 0 then return nil, "No bindings found in that text." end
    return pairsOut
end

-- Wipes what is there and lays the imported set down in its place. Nothing
-- is written to disk until Save map, so Discard changes undoes all of it.
function ns.ApplyImport(list)
    local ok, why = ns.CanEdit()
    if not ok then return false, why end

    -- A couple of hundred bindings go through here, so this writes them
    -- directly and rescans once at the end rather than rebuilding the whole
    -- model after every single key.
    local function bindable(binding)
        local key = ns.Split(binding)
        return ns.IsBindableKey(key)
    end

    -- Clear first, or anything the import does not mention would survive it
    -- and the result would be a merge, not the set that was handed over.
    -- Left and right click are left alone: they are not ours to empty.
    local wipe = {}
    for i = 1, GetNumBindings() do
        local command = GetBinding(i)
        if type(command) == "string" and command ~= ""
            and not command:find("^HEADER_") then
            local a, b = GetBindingKey(command)
            if a and bindable(a) then wipe[#wipe + 1] = a end
            if b and bindable(b) then wipe[#wipe + 1] = b end
        end
    end
    for _, binding in ipairs(wipe) do SetBinding(binding) end

    local applied, refused = 0, 0
    for _, entry in ipairs(list) do
        if bindable(entry.binding) and SetBinding(entry.binding, entry.command) then
            applied = applied + 1
        else
            refused = refused + 1
        end
    end

    -- Whatever the import did or did not say about them, those two buttons
    -- end up doing what the game expects of them.
    for _, key in ipairs({ "BUTTON1", "BUTTON2" }) do
        local want = ns.ReservedDefault(key)
        if want and GetBindingAction(key) ~= want then SetBinding(key, want) end
    end

    ns.MarkDirty()
    ns.Scan()
    return true, applied, refused
end

----------------------------------------------------------------------
-- The box
----------------------------------------------------------------------
local function Build()
    win = CreateFrame("Frame", "DaylightKeymapTransfer", UIParent)
    win:SetSize(560, 460)
    win:SetPoint("CENTER")
    win:SetFrameStrata("FULLSCREEN_DIALOG")
    win:EnableMouse(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    API.Skin(win, { window = true })
    win:Hide()

    local handle = CreateFrame("Frame", nil, win)
    handle:SetPoint("TOPLEFT"); handle:SetPoint("TOPRIGHT", -100, 0)
    handle:SetHeight(44)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function() if not InCombatLockdown() then win:StartMoving() end end)
    handle:SetScript("OnDragStop", function() win:StopMovingOrSizing() end)

    win.title = API.Text(win, "title", "LEFT")
    win.title:SetPoint("TOPLEFT", 20, -16)

    local close = API.Button(win, "Close", 24)
    close:SetWidth(78)
    close:SetPoint("TOPRIGHT", -16, -14)
    close:SetScript("OnClick", function() win:Hide() end)

    win.help = API.Text(win, "small", "LEFT")
    win.help:SetPoint("TOPLEFT", 20, -52)
    win.help:SetWidth(520)
    win.help:SetTextColor(0.6, 0.66, 0.75)

    -- the text itself
    local pane = CreateFrame("Frame", nil, win)
    pane:SetPoint("TOPLEFT", 20, -104)
    pane:SetPoint("BOTTOMRIGHT", -20, 56)
    pane.bg = pane:CreateTexture(nil, "BACKGROUND")
    pane.bg:SetAllPoints()
    pane.bg:SetColorTexture(0.055, 0.063, 0.082, 1)

    local scroll = CreateFrame("ScrollFrame", "DaylightKeymapTransferScroll", pane,
        "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(0)
    edit:SetWidth(480)
    edit:SetTextInsets(2, 2, 2, 2)
    edit:SetFontObject(ChatFontNormal)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(edit)
    win.edit = edit

    -- actions
    win.action = API.Button(win, "Replace my bindings", 26)
    win.action:SetWidth(170)
    win.action:SetPoint("BOTTOMRIGHT", -20, 16)
    win.action:SetScript("OnClick", function()
        local list, why = ns.ParseImport(win.edit:GetText())
        if not list then Say(why); return end

        local good, applied, refused = ns.ApplyImport(list)
        if not good then Say(applied); return end

        Say(applied .. " bindings applied"
            .. (refused > 0 and (", " .. refused .. " refused") or "")
            .. ". Nothing is saved yet: Discard changes on the map puts your old set back.")
        win:Hide()
        if ns.Refresh then ns.Refresh() end
    end)

    win.selectAll = API.Button(win, "Select all", 26)
    win.selectAll:SetWidth(110)
    win.selectAll:SetPoint("BOTTOMRIGHT", -20, 16)
    win.selectAll:SetScript("OnClick", function()
        win.edit:SetFocus()
        win.edit:HighlightText()
    end)

    win.note = API.Text(win, "tiny", "LEFT")
    win.note:SetPoint("BOTTOMLEFT", 20, 24)
    win.note:SetWidth(340)
    win.note:SetTextColor(0.42, 0.46, 0.52)
end

----------------------------------------------------------------------
-- Modes
----------------------------------------------------------------------
function ns.ShowExport()
    if not win then Build() end

    local text, count = ns.ExportString()
    win.title:SetText("Export bindings")
    win.help:SetText("Every binding you have, one per line. Select all, copy with Ctrl+C, and paste it into a text file to keep.")
    win.note:SetText(count .. " bindings. Plain text, so you can read and edit it.")
    win.edit:SetText(text)
    win.action:Hide()
    win.selectAll:Show()

    win:Show()
    win:Raise()
    win.edit:SetFocus()
    win.edit:HighlightText()
end

function ns.ShowImport()
    if not win then Build() end

    win.title:SetText("Import bindings")
    win.help:SetText("Paste an export here with Ctrl+V, then press Replace. Everything you have now is swapped for what you paste.")
    win.note:SetText("Nothing is written until you press Save map, so Discard changes undoes an import you did not like.")
    win.edit:SetText("")
    win.selectAll:Hide()
    win.action:Show()

    win:Show()
    win:Raise()
    win.edit:SetFocus()
end

my.RegisterCommand("keymapexport", function() ns.ShowExport() end,
    "Copy your bindings out as text")
my.RegisterCommand("keymapimport", function() ns.ShowImport() end,
    "Paste bindings back in")
