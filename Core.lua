-- DaylightKeymap
-- Core.lua — plugin registration, settings module, slash command.

local ADDON, ns = ...

ns.NAME  = "DaylightKeymap"
ns.LABEL = "Keymap"
ns.TAG   = "|cffe8a33dKeymap|r "

----------------------------------------------------------------------
-- Say hello to Daylight UI.
-- needs = { 1, 5 } because the highest thing we use is API.ButtonInfo,
-- which arrived in 1.5. Declaring the lowest version that works means
-- the plugin runs on as many installs as possible.
----------------------------------------------------------------------
DaylightUI:RegisterPlugin(ns.NAME, {
    needs = { 1, 5 },
    icon  = "Interface\\AddOns\\DaylightKeymap\\icon.png",
    color = "e8a33d",
    short = "Keymap",
})

local API = DaylightUI.API
local my  = API.For(ns.NAME)

ns.API = API
ns.my  = my

----------------------------------------------------------------------
-- Settings
----------------------------------------------------------------------
local DEFAULTS = {
    layout       = "ansi",    -- ansi | iso
    size         = "tkl",     -- full | tkl | sixty
    mouseButtons = 5,         -- 3 .. 12
    allLayers    = false,     -- false = 4 layers, true = all 8
    scope        = "account", -- account | character
    showCounts   = true,
    dimUnbound   = true,
}

function ns.Get(key)
    local v = API.GetSetting(ns.NAME, key)
    if v == nil then return DEFAULTS[key] end
    return v
end

-- Layers the map draws. The three-modifier combos are hidden by default:
-- they are awkward to hit mid-fight and they make the free-slot counter
-- meaningless.
local LAYERS_4 = { "", "S", "C", "A" }
local LAYERS_8 = { "", "S", "C", "A", "SC", "SA", "CA", "SCA" }

function ns.Layers()
    return ns.Get("allLayers") and LAYERS_8 or LAYERS_4
end

DaylightUI:RegisterModule(ns.NAME, {
    plugin   = ns.NAME,
    label    = ns.LABEL,
    defaults = DEFAULTS,

    options = { pages = {
        {
            id = "main", label = ns.LABEL,
            desc = "A map of your keyboard and mouse showing every key that is taken.",
            groups = {
                {
                    label = "Windows",
                    items = {
                        { type = "button", label = "Open the keymap",
                          desc = "The keyboard and mouse map. Also on /dui keymap.",
                          func = function() ns.ShowPanel() end },

                        { type = "button", label = "Bind on hover",
                          desc = "Point at a button on one of Daylight UI's action bars and press the combo you want. Also on /dui bindhover.",
                          func = function() ns.ToggleHoverBind() end },
                    },
                },
                {
                    label = "Your keyboard",
                    items = {
                        { type = "dropdown", key = "layout", label = "Layout",
                          desc = "ISO has an extra key left of Z and a tall Enter. ANSI does not.",
                          values = { ansi = "ANSI", iso = "ISO" } },

                        { type = "dropdown", key = "size", label = "Size",
                          desc = "Keys your board has no cap for are still bindable; a 60% board shows them in an overflow strip.",
                          values = { full = "Full-size", tkl = "Tenkeyless", sixty = "60%" } },
                    },
                },
                {
                    label = "Your mouse",
                    items = {
                        { type = "slider", key = "mouseButtons", label = "Buttons",
                          desc = "Count every button the mouse has, thumb pad included. The wheel is always drawn.",
                          min = 3, max = 12, step = 1 },
                    },
                },
                {
                    label = "The map",
                    items = {
                        { type = "toggle", key = "allLayers", label = "Show all eight layers",
                          desc = "Off: no modifier, Shift, Ctrl and Alt. On: adds the three-modifier combos too." },

                        { type = "toggle", key = "showCounts", label = "Count on each key",
                          desc = "A small number in the corner saying how many layers of that key are taken." },

                        { type = "toggle", key = "dimUnbound", label = "Dim free keys",
                          desc = "Off: free keys are drawn as brightly as taken ones." },

                        { type = "dropdown", key = "scope", label = "Save bindings to",
                          desc = "Account bindings follow every character. Character bindings are this one's alone.",
                          values = { account = "Account", character = "This character" } },
                    },
                },
            },
        },

    } },

    OnEnable = function() end,
})

----------------------------------------------------------------------
-- /dui keymap
----------------------------------------------------------------------
my.RegisterCommand("keymap", function()
    ns.TogglePanel()
end, "Open the keymap")

-- A way back if left or right click ever stops looking, moving or selecting.
-- /dui keybinds used to open a second window. It opens the map instead,
-- which carries the whole list now.
my.RegisterCommand("keybinds", function()
    ns.ShowPanel()
end, "Open the keymap and its list of actions")

my.RegisterCommand("keymapfix", function()
    local ok, result = ns.RestoreMouseDefaults()
    if not ok then
        print(ns.TAG .. result)
    elseif result == 0 then
        print(ns.TAG .. "Left and right click are already doing the game's own job.")
    else
        print(ns.TAG .. "Put " .. result .. " mouse button(s) back to the game's default.")
    end
end, "Put left and right click back to the game's defaults")

-- If categories ever come out wrong, this prints what the game actually
-- hands back so the mapping can be fixed against real data.
my.RegisterCommand("keymapraw", function()
    print(ns.TAG .. "GetBinding, first 24 entries: index | command | second | third")
    for i = 1, math.min(24, GetNumBindings()) do
        local a, b, c = GetBinding(i)
        print(("  %d | %s | %s | %s"):format(i, tostring(a), tostring(b), tostring(c)))
    end
end, "Print raw binding data, for reporting a problem")

my.On("StyleChanged", function()
    if ns.Restyle then ns.Restyle() end
end)
