-- DaylightKeymap
-- Layouts.lua — the physical boards we can draw.
--
-- Everything is placed on a grid measured in key units, so the nav cluster
-- and the numpad sit in fixed columns instead of drifting with whatever
-- the row before them happened to be.
--
-- `key` is WoW's own name for the key, the one GetBindingAction wants.

local ADDON, ns = ...

local function k(key, label, w) return { key = key, label = label or key, w = w or 1 } end
local function mod(label, w)    return { label = label, w = w or 1.25, mod = true } end
local function gap(w)           return { gap = w or 0.5 } end
local function hole(w)          return { blank = true, w = w or 1 } end

local MAIN_W = 15       -- every main-block row is fifteen units wide
local NAV_X  = 15.5     -- the Ins/Del/arrow cluster
local PAD_X  = 19.5     -- the numpad

----------------------------------------------------------------------
-- Rows
----------------------------------------------------------------------

local FUNCTION_ROW = {
    k("ESCAPE", "Esc"), gap(1),
    k("F1"), k("F2"), k("F3"), k("F4"), gap(0.5),
    k("F5"), k("F6"), k("F7"), k("F8"), gap(0.5),
    k("F9"), k("F10"), k("F11"), k("F12"),
}

local NUMBER_ROW = {
    k("`", "`"), k("1"), k("2"), k("3"), k("4"), k("5"), k("6"),
    k("7"), k("8"), k("9"), k("0"), k("-"), k("=", "="),
    k("BACKSPACE", "Bksp", 2),
}

-- Win, Fn and Menu join the modifiers as keys you cannot bind: Windows
-- swallows the first, the keyboard never sends Fn to the operating system
-- at all, and WoW has no name for the context-menu key.
local BOTTOM_ROW = {
    mod("Ctrl", 1.25), mod("Win", 1.25), mod("Alt", 1.25),
    k("SPACE", "Space", 6.25),
    mod("Alt", 1.25), mod("Fn", 1.25), mod("Menu", 1.25), mod("Ctrl", 1.25),
}

local function AnsiRows()
    return {
        { k("TAB", "Tab", 1.5), k("Q"), k("W"), k("E"), k("R"), k("T"), k("Y"),
          k("U"), k("I"), k("O"), k("P"), k("["), k("]"), k("\\", "\\", 1.5) },

        { k("CAPSLOCK", "Caps", 1.75), k("A"), k("S"), k("D"), k("F"), k("G"),
          k("H"), k("J"), k("K"), k("L"), k(";"), k("'"), k("ENTER", "Enter", 2.25) },

        { mod("Shift", 2.25), k("Z"), k("X"), k("C"), k("V"), k("B"), k("N"),
          k("M"), k(","), k("."), k("/"), mod("Shift", 2.75) },
    }
end

-- ISO: an extra key left of Z, and a tall Enter. We draw Enter on the
-- upper of the two rows it spans and leave a hole under it.
--
-- WoW's names for the two extra keys depend on the board and the OS
-- layout, so these are a starting guess. Tell me what they really are
-- and they get fixed in a line.
local function IsoRows()
    return {
        { k("TAB", "Tab", 1.5), k("Q"), k("W"), k("E"), k("R"), k("T"), k("Y"),
          k("U"), k("I"), k("O"), k("P"), k("["), k("]"), k("ENTER", "Enter", 1.5) },

        { k("CAPSLOCK", "Caps", 1.75), k("A"), k("S"), k("D"), k("F"), k("G"),
          k("H"), k("J"), k("K"), k("L"), k(";"), k("'"), k("\\", "#"), hole(1.25) },

        { mod("Shift", 1.25), k("`", "<"), k("Z"), k("X"), k("C"), k("V"), k("B"),
          k("N"), k("M"), k(","), k("."), k("/"), mod("Shift", 2.75) },
    }
end

----------------------------------------------------------------------
-- Placing
----------------------------------------------------------------------

local function emit(places, row, x0, entries)
    local x = x0
    for _, e in ipairs(entries) do
        if e.gap then
            x = x + e.gap
        elseif e.blank then
            x = x + (e.w or 1)
        else
            places[#places + 1] = {
                key = e.key, label = e.label, w = e.w or 1,
                x = x, y = row, mod = e.mod,
            }
            x = x + (e.w or 1)
        end
    end
    return x
end

-- Keys a 60% board has no cap for, but which WoW will still bind.
local OVERFLOW = {
    "F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12",
    "INSERT","HOME","PAGEUP","DELETE","END","PAGEDOWN",
    "UP","DOWN","LEFT","RIGHT","PRINTSCREEN","SCROLLLOCK","PAUSE",
}

local OVERFLOW_LABEL = {
    INSERT = "Ins", HOME = "Home", PAGEUP = "PgUp",
    DELETE = "Del", END = "End", PAGEDOWN = "PgDn",
    UP = "Up", DOWN = "Dn", LEFT = "Lt", RIGHT = "Rt",
    PRINTSCREEN = "PrtSc", SCROLLLOCK = "Scrl", PAUSE = "Paus",
}

-- Returns places, rowCount, widthInUnits, overflowKeys
function ns.BuildBoard()
    local layout = ns.Get("layout")
    local size   = ns.Get("size")
    local sixty  = (size == "sixty")
    local full   = (size == "full")

    local letters = (layout == "iso") and IsoRows() or AnsiRows()
    local places = {}

    -- main block ------------------------------------------------------
    local row = 0
    if not sixty then
        emit(places, row, 0, FUNCTION_ROW)
        row = row + 1
    end
    local firstBodyRow = row

    emit(places, row, 0, NUMBER_ROW);   row = row + 1
    emit(places, row, 0, letters[1]);   row = row + 1
    emit(places, row, 0, letters[2]);   row = row + 1
    emit(places, row, 0, letters[3]);   row = row + 1
    emit(places, row, 0, BOTTOM_ROW);   row = row + 1

    local rowCount = row
    local width = MAIN_W

    -- nav cluster and arrows, in their own fixed column ---------------
    if not sixty then
        emit(places, 0, NAV_X, { k("PRINTSCREEN", "PrtSc"), k("SCROLLLOCK", "Scrl"), k("PAUSE", "Paus") })
        emit(places, firstBodyRow,     NAV_X, { k("INSERT", "Ins"), k("HOME", "Home"), k("PAGEUP", "PgUp") })
        emit(places, firstBodyRow + 1, NAV_X, { k("DELETE", "Del"), k("END", "End"), k("PAGEDOWN", "PgDn") })
        -- the arrow cluster sits on the last two rows, under the nav block
        emit(places, rowCount - 2, NAV_X, { hole(1), k("UP", "Up"), hole(1) })
        emit(places, rowCount - 1, NAV_X, { k("LEFT", "Lt"), k("DOWN", "Dn"), k("RIGHT", "Rt") })
        width = NAV_X + 3
    end

    -- numpad ----------------------------------------------------------
    if full then
        emit(places, firstBodyRow,     PAD_X, { k("NUMLOCK", "Num"), k("NUMPADDIVIDE", "/"), k("NUMPADMULTIPLY", "*"), k("NUMPADMINUS", "-") })
        emit(places, firstBodyRow + 1, PAD_X, { k("NUMPAD7", "7"), k("NUMPAD8", "8"), k("NUMPAD9", "9"), k("NUMPADPLUS", "+") })
        emit(places, firstBodyRow + 2, PAD_X, { k("NUMPAD4", "4"), k("NUMPAD5", "5"), k("NUMPAD6", "6") })
        emit(places, firstBodyRow + 3, PAD_X, { k("NUMPAD1", "1"), k("NUMPAD2", "2"), k("NUMPAD3", "3"), k("NUMPADENTER", "Ent") })
        emit(places, firstBodyRow + 4, PAD_X, { k("NUMPAD0", "0", 2), k("NUMPADDECIMAL", ".") })
        width = PAD_X + 4
    end

    local overflow = nil
    if sixty then
        overflow = {}
        for _, name in ipairs(OVERFLOW) do
            overflow[#overflow + 1] = k(name, OVERFLOW_LABEL[name] or name)
        end
    end

    return places, rowCount, width, overflow
end

----------------------------------------------------------------------
-- Mouse
--
-- Three buttons on the mouse itself, the thumb buttons stacked to its
-- left, the wheel to its right.
----------------------------------------------------------------------

function ns.BuildMouse()
    local count = tonumber(ns.Get("mouseButtons")) or 5
    if count < 3 then count = 3 end
    if count > 12 then count = 12 end

    -- WoW's binding system will not take BUTTON1 or BUTTON2, with or
    -- without modifiers; they belong to looking, moving and clicking. Every
    -- other mouse button binds normally, modifiers included.
    local core = {
        { key = "BUTTON1", label = "LMB", part = "left",  locked = true },
        { key = "BUTTON2", label = "RMB", part = "right", locked = true },
        { key = "BUTTON3", label = "MMB", part = "wheel" },
    }

    local left = {}
    for i = 4, count do
        left[#left + 1] = { key = "BUTTON" .. i, label = "Mouse " .. i }
    end

    local right = {
        { key = "MOUSEWHEELUP",   label = "Wheel Up" },
        { key = "MOUSEWHEELDOWN", label = "Wheel Dn" },
    }

    return core, left, right
end
