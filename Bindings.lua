-- DaylightKeymap
-- Bindings.lua — reading the game's bindings, and writing them back.
--
-- Nothing here touches a file. The game is asked directly, so the map is
-- always current and no logout is needed.

local ADDON, ns = ...

local ACCOUNT_SET, CHARACTER_SET = 1, 2

----------------------------------------------------------------------
-- Key strings
--
-- WoW writes a combination as ALT-CTRL-SHIFT-KEY, always in that order.
-- We carry the modifiers around as a short layer code: "", "S", "C",
-- "A", "SC", "SA", "CA", "SCA".
----------------------------------------------------------------------

function ns.Compose(key, layer)
    local prefix = ""
    if layer:find("A") then prefix = prefix .. "ALT-" end
    if layer:find("C") then prefix = prefix .. "CTRL-" end
    if layer:find("S") then prefix = prefix .. "SHIFT-" end
    return prefix .. key
end

function ns.Split(binding)
    local rest, shift, ctrl, alt = binding, false, false, false
    while true do
        local prefix, remainder = rest:match("^(%u+)%-(.+)$")
        if prefix == "ALT" then alt = true; rest = remainder
        elseif prefix == "CTRL" then ctrl = true; rest = remainder
        elseif prefix == "SHIFT" then shift = true; rest = remainder
        else break end
    end
    local layer = (shift and "S" or "") .. (ctrl and "C" or "") .. (alt and "A" or "")
    return rest, layer
end

-- Short names, for the places where a key has to fit in a small box.
local SHORT = {
    MOUSEWHEELUP = "Whl Up", MOUSEWHEELDOWN = "Whl Dn",
    BUTTON1 = "LMB", BUTTON2 = "RMB", BUTTON3 = "MMB",
    ESCAPE = "Esc", BACKSPACE = "Bksp", CAPSLOCK = "Caps", ENTER = "Enter",
    SPACE = "Space", TAB = "Tab", NUMLOCK = "Num",
    INSERT = "Ins", DELETE = "Del", HOME = "Home", END = "End",
    PAGEUP = "PgUp", PAGEDOWN = "PgDn",
    PRINTSCREEN = "PrtSc", SCROLLLOCK = "Scrl", PAUSE = "Paus",
    UP = "Up", DOWN = "Dn", LEFT = "Lt", RIGHT = "Rt",
}

function ns.ShortKeyName(key)
    if not key or key == "" then return "-" end
    if SHORT[key] then return SHORT[key] end
    local n = key:match("^BUTTON(%d+)$")
    if n then return "M" .. n end
    local pad = key:match("^NUMPAD(.+)$")
    if pad then return "#" .. (pad:sub(1, 3)) end
    if #key <= 5 then return key end
    return key:sub(1, 5)
end

-- "No mod" / "Shift" / "Shift+Ctrl" — the key itself is already in the
-- header above the list, so the rows only need the modifier.
function ns.ModShort(layer)
    if layer == "" then return "No mod" end
    local parts = {}
    if layer:find("S") then parts[#parts + 1] = "Shift" end
    if layer:find("C") then parts[#parts + 1] = "Ctrl" end
    if layer:find("A") then parts[#parts + 1] = "Alt" end
    return table.concat(parts, "+")
end

-- "Shift+Z", "Ctrl+Whl Up", "C" — a binding string in a form that fits on
-- a tag beside an action's name.
function ns.PrettyBinding(binding)
    if not binding or binding == "" then return nil end
    local key, layer = ns.Split(binding)
    local short = ns.ShortKeyName(key)
    if layer == "" then return short end
    return ns.ModShort(layer) .. "+" .. short
end

-- The one or two keys the game has on a command right now.
function ns.KeysForCommand(command)
    if not command then return nil end
    local a, b = GetBindingKey(command)
    return a, b
end

-- Every command grouped under its category header, in the game's own
-- order, which is what the Keybindings window lists.
function ns.CommandGroups()
    local groups, index = {}, {}
    for _, entry in ipairs(ns.commands or {}) do
        local cat = (entry.category ~= "" and entry.category)
                 or MISCELLANEOUS or "Miscellaneous"
        local g = index[cat]
        if not g then
            g = { name = cat, items = {} }
            index[cat] = g
            groups[#groups + 1] = g
        end
        g.items[#g.items + 1] = entry
    end
    return groups
end

function ns.LayerLabel(layer)
    if layer == "" then return "no modifier" end
    local parts = {}
    if layer:find("S") then parts[#parts + 1] = "Shift" end
    if layer:find("C") then parts[#parts + 1] = "Ctrl" end
    if layer:find("A") then parts[#parts + 1] = "Alt" end
    return table.concat(parts, "+")
end

-- The layer the player is holding down right now.
function ns.CurrentLayer()
    return (IsShiftKeyDown() and "S" or "")
        .. (IsControlKeyDown() and "C" or "")
        .. (IsAltKeyDown() and "A" or "")
end

----------------------------------------------------------------------
-- Command names
----------------------------------------------------------------------

function ns.CommandName(command)
    if not command then return "" end
    local name = _G["BINDING_NAME_" .. command]
    if name then return name end
    if GetBindingName then
        local ok, n = pcall(GetBindingName, command)
        if ok and n and n ~= "" then return n end
    end
    -- An addon's own binding with no name set, or a click binding.
    return (command:gsub("^CLICK ", ""):gsub("_", " "))
end

-- A header's display name, or nil when it is one of the game's spacers.
-- Blizzard pads its binding list with HEADER_BLANK1, HEADER_BLANK2 and so
-- on; those have no name and must not start a category of their own.
local function HeaderName(command)
    local raw = command:gsub("^HEADER_", "")
    if raw:find("^BLANK") then return nil end
    local name = _G["BINDING_HEADER_" .. raw]
    if name and name ~= "" then return name end
    return nil
end

----------------------------------------------------------------------
-- Which categories came from an addon
--
-- A binding header's display name is the addon's own name, so matching it
-- against the installed addons tells us whether an action is the game's or
-- someone else's. The game's own actions need no source tag.
----------------------------------------------------------------------

local addonNames

local function Normalize(s)
    if type(s) ~= "string" then return nil end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" then return nil end
    return s:lower()
end

local function AddonNameSet()
    if addonNames then return addonNames end
    addonNames = {}

    local getNum  = (C_AddOns and C_AddOns.GetNumAddOns) or GetNumAddOns
    local getInfo = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
    if not getNum or not getInfo then return addonNames end

    for i = 1, getNum() do
        local ok, folder, title = pcall(getInfo, i)
        if ok then
            local a, b = Normalize(folder), Normalize(title)
            if a then addonNames[a] = true end
            if b then addonNames[b] = true end
        end
    end
    return addonNames
end

-- Letters and digits only, so "DUI_Mogul", "DUI Mogul" and "Mogul" all
-- squash to something comparable.
local function Squash(s)
    local n = Normalize(s)
    if not n then return nil end
    n = n:gsub("[^%w]", "")
    if n == "" then return nil end
    return n
end

function ns.IsAddonCategory(category)
    local exact = Normalize(category)
    if not exact then return false end

    local set = AddonNameSet()
    if set[exact] then return true end

    -- An addon's binding header is rarely its folder name to the letter:
    -- it drops a prefix, adds a word, or spaces things differently. Fall
    -- back to one name containing the other, with a length floor so short
    -- category names the game owns ("Chat", "Camera") cannot collide with
    -- an addon that happens to share the word.
    local a = Squash(category)
    if not a or #a < 5 then return false end

    for name in pairs(set) do
        local b = Squash(name)
        if b and #b >= 5 then
            if a:find(b, 1, true) or b:find(a, 1, true) then return true end
        end
    end
    return false
end

----------------------------------------------------------------------
-- Reading
--
-- GetBinding's return shape has changed between clients: older ones give
-- (command, key1, key2), newer ones slip a category in as the second
-- value. Rather than guess, we keep only the values that GetBindingAction
-- agrees are bound to this command. That is true on every client.
----------------------------------------------------------------------

local function KeysFor(index, command)
    local rets = { GetBinding(index) }
    local keys = {}
    for i = 2, #rets do
        local v = rets[i]
        if type(v) == "string" and v ~= "" and GetBindingAction(v) == command then
            keys[#keys + 1] = v
        end
    end
    return keys
end

-- ns.map[physicalKey][layer] = { command = ..., name = ..., category = ... }
-- ns.commands = ordered list of every bindable command, for the search box.
-- The category this binding belongs to, straight from the game.
--
-- Modern clients return it as GetBinding's second value, usually the token
-- BINDING_HEADER_MOVEMENT and so on, which resolves to the same words
-- Blizzard's own options show. Older clients return key1 there instead, so
-- anything that turns out to be a key bound to this very command is
-- rejected and we fall back to walking the HEADER_ entries.
local function CategoryFor(index, command)
    local _, second = GetBinding(index)
    if type(second) ~= "string" or second == "" then return nil end
    if GetBindingAction(second) == command then return nil end   -- it is a key

    local name = _G[second]
    if type(name) == "string" and name ~= "" then return name end

    if not second:find("^BINDING_") then return second end       -- already readable

    local raw = second:gsub("^BINDING_HEADER_", "")
    if raw:find("^BLANK") then return nil end
    raw = raw:gsub("_", " ")
    return raw:sub(1, 1) .. raw:sub(2):lower()
end

function ns.Scan()
    local map, commands = {}, {}
    local walked = ""     -- category from walking HEADER_ entries

    for i = 1, GetNumBindings() do
        local command = GetBinding(i)
        if type(command) == "string" and command ~= "" then
            if command:find("^HEADER_") then
                -- a spacer leaves the current category alone
                walked = HeaderName(command) or walked
            else
                local category = CategoryFor(i, command) or walked
                if category == "" then
                    category = MISCELLANEOUS or "Miscellaneous"
                end
                local name = ns.CommandName(command)
                commands[#commands + 1] = {
                    command  = command,
                    name     = name,
                    category = category,
                }

                for _, binding in ipairs(KeysFor(i, command)) do
                    local key, layer = ns.Split(binding)
                    map[key] = map[key] or {}
                    map[key][layer] = { command = command, name = name, category = category }
                end
            end
        end
    end

    ns.map = map
    ns.commands = commands
    return map, commands
end

-- How many of the layers we draw are taken on this key.
function ns.CountFor(key)
    local slots = ns.map and ns.map[key]
    if not slots then return 0 end
    local n = 0
    for _, layer in ipairs(ns.Layers()) do
        if slots[layer] then n = n + 1 end
    end
    return n
end

-- Bindings sitting on layers the map is not currently drawing. Worth
-- surfacing so a "free" key is never a lie.
function ns.HiddenCountFor(key)
    local slots = ns.map and ns.map[key]
    if not slots then return 0 end
    local shown = {}
    for _, layer in ipairs(ns.Layers()) do shown[layer] = true end
    local n = 0
    for layer in pairs(slots) do
        if not shown[layer] then n = n + 1 end
    end
    return n
end

-- How many of the game's bindable actions have a key on them. This counts
-- actions, not keys: an action with two keys still counts once.
function ns.ActionTotals()
    local bound, total = 0, 0
    for _, entry in ipairs(ns.commands or {}) do
        total = total + 1
        if GetBindingKey(entry.command) then bound = bound + 1 end
    end
    return bound, total
end

-- Exactly which keys the free-keys counter is counting. Mouse buttons are
-- keys too, which is usually what makes the number look wrong.
function ns.FreeKeyList()
    local places, _, _, overflow = ns.BuildBoard()
    local seen, out = {}, {}

    local function add(key)
        if not key or seen[key] then return end
        seen[key] = true
        if ns.CountFor(key) == 0 then out[#out + 1] = key end
    end

    for _, place in ipairs(places) do add(place.key) end
    if overflow then for _, entry in ipairs(overflow) do add(entry.key) end end

    local core, left, right = ns.BuildMouse()
    for _, e in ipairs(core) do if not e.locked then add(e.key) end end
    for _, e in ipairs(left) do add(e.key) end
    for _, e in ipairs(right) do add(e.key) end

    table.sort(out)
    return out
end

function ns.Totals()
    local bound, slots = 0, 0
    local layers = #ns.Layers()
    local places, _, _, overflow = ns.BuildBoard()
    local seen = {}

    local function count(key)
        if not key or seen[key] then return end
        seen[key] = true
        slots = slots + layers
        bound = bound + ns.CountFor(key)
    end

    for _, place in ipairs(places) do count(place.key) end
    if overflow then
        for _, entry in ipairs(overflow) do count(entry.key) end
    end
    local core, left, right = ns.BuildMouse()
    for _, e in ipairs(core) do if not e.locked then count(e.key) end end
    for _, e in ipairs(left) do count(e.key) end
    for _, e in ipairs(right) do count(e.key) end

    local freeKeys = 0
    for key in pairs(seen) do
        if ns.CountFor(key) == 0 then freeKeys = freeKeys + 1 end
    end

    return bound, freeKeys, slots - bound
end

----------------------------------------------------------------------
-- Writing
--
-- SetBinding is blocked during combat lockdown on the modern client, so
-- every write goes through here and refuses politely in a fight.
----------------------------------------------------------------------

function ns.TargetSet()
    return (ns.Get("scope") == "character") and CHARACTER_SET or ACCOUNT_SET
end

function ns.CanEdit()
    if InCombatLockdown() then return false, "Bindings cannot be changed in combat." end
    return true
end

local dirty = false

-- Bind a whole binding string ("SHIFT-Z"). Returns true, plus whatever
-- command lost that key, so the caller can say what it took away.
function ns.AssignBinding(binding, command)
    local ok, why = ns.CanEdit()
    if not ok then return false, why end

    local previous = GetBindingAction(binding)
    if not SetBinding(binding, command) then
        return false, "The game refused that key."
    end

    dirty = true
    ns.Scan()
    return true, (previous ~= "" and previous ~= command) and previous or nil
end

function ns.ClearBinding(binding)
    local ok, why = ns.CanEdit()
    if not ok then return false, why end
    if GetBindingAction(binding) == "" then return true end

    SetBinding(binding, nil)
    dirty = true
    ns.Scan()
    return true
end

function ns.Assign(key, layer, command)
    return ns.AssignBinding(ns.Compose(key, layer), command)
end

function ns.Clear(key, layer)
    return ns.ClearBinding(ns.Compose(key, layer))
end

function ns.IsDirty() return dirty end

function ns.Save()
    if not dirty then return true end
    local ok, why = ns.CanEdit()
    if not ok then return false, why end
    SaveBindings(ns.TargetSet())
    dirty = false
    return true
end

function ns.Discard()
    if not dirty then return true end
    LoadBindings(GetCurrentBindingSet())
    dirty = false
    ns.Scan()
    return true
end

----------------------------------------------------------------------
-- Action bars
--
-- Dragging a button off one of Daylight UI's bars onto the map should
-- bind that button's command. Only bars 1 to 8 are Daylight UI's own;
-- the stance and pet bars are the game's, so they are left alone.
----------------------------------------------------------------------

local BAR_COMMANDS = {
    main = "ACTIONBUTTON",
    bar1 = "ACTIONBUTTON",
    bar2 = "MULTIACTIONBAR1BUTTON",
    bar3 = "MULTIACTIONBAR2BUTTON",
    bar4 = "MULTIACTIONBAR3BUTTON",
    bar5 = "MULTIACTIONBAR4BUTTON",
    bar6 = "MULTIACTIONBAR5BUTTON",
    bar7 = "MULTIACTIONBAR6BUTTON",
    bar8 = "MULTIACTIONBAR7BUTTON",
}

local BAR_BY_NUMBER = {
    "ACTIONBUTTON",
    "MULTIACTIONBAR1BUTTON", "MULTIACTIONBAR2BUTTON", "MULTIACTIONBAR3BUTTON",
    "MULTIACTIONBAR4BUTTON", "MULTIACTIONBAR5BUTTON", "MULTIACTIONBAR6BUTTON",
    "MULTIACTIONBAR7BUTTON",
}

-- No `empty` check here: while an action is being dragged its slot IS
-- empty, which is exactly when we need to read the button.
local function CommandForButtonInfo(info)
    if not info then return nil end
    local prefix = (info.barKey and BAR_COMMANDS[info.barKey])
                or (info.bar and BAR_BY_NUMBER[info.bar])
    if not prefix or not info.index then return nil end
    return prefix .. info.index
end

-- Which button a drag started from. GetCursorInfo only ever describes what
-- is on the cursor (a spell, an item, a macro) and never which action slot
-- it came from, so the button has to be remembered as the drag begins.
function ns.NoteDragSource(frame)
    ns.dragFrom = frame
end

function ns.ForgetDragSource()
    ns.dragFrom = nil
end

-- The action bar button currently being dragged, as a binding command.
function ns.CommandOnCursor()
    if not GetCursorInfo() then
        ns.dragFrom = nil
        return nil
    end
    if not ns.dragFrom then return nil end

    local ok, info = pcall(ns.API.ButtonInfo, ns.dragFrom)
    if not ok then return nil end

    local command = CommandForButtonInfo(info)
    if not command then return nil end
    return command, ns.CommandName(command)
end
