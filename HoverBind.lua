-- DaylightKeymap
-- HoverBind.lua — point at an action bar button, press a combo, it binds.
--
-- No hooks on Daylight UI's buttons: the frame under the mouse is asked for
-- at the moment the key goes down, which is the only moment it matters.

local ADDON, ns = ...
local API, my = ns.API, ns.my

local frame, banner
local active, lit = false, nil

local function Say(msg) print(ns.TAG .. msg) end

local IGNORED = {
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
    LALT = true, RALT = true, UNKNOWN = true,
}

----------------------------------------------------------------------
-- What the mouse is over
----------------------------------------------------------------------
local function MouseFrame()
    if GetMouseFoci then
        local foci = GetMouseFoci()
        return foci and foci[1] or nil
    end
    if GetMouseFocus then return GetMouseFocus() end
    return nil
end

local function HoveredButton()
    local under = MouseFrame()
    if not under then return nil end

    -- the frame under the cursor, or the button it sits inside
    for _ = 1, 4 do
        if not under or under == UIParent then break end
        local command, name = ns.CommandForFrame(under)
        if command then return under, command, name end
        under = under.GetParent and under:GetParent() or nil
    end
    return nil
end

-- A glow follows the button you are pointing at, so there is never a doubt
-- about which one a keypress is going to land on.
local function Light(button)
    if lit == button then return end
    if lit then pcall(API.Glow, lit, false) end
    lit = button
    if lit then pcall(API.Glow, lit, true, API.Accent()) end
end

----------------------------------------------------------------------
-- Binding
----------------------------------------------------------------------
local function Take(keyName)
    if keyName == "ESCAPE" then ns.StopHoverBind(); return end
    if IGNORED[keyName] then return end

    local button, command, name = HoveredButton()
    if not command then
        Say("Point at a button on one of Daylight UI's action bars first.")
        return
    end

    local binding = ns.Compose(keyName, ns.CurrentLayer())
    local pretty  = ns.PrettyBinding(binding)

    -- Say what the key is already doing before taking it, which is the
    -- whole point of binding from inside a keymap.
    local held = GetBindingAction(binding)
    if held ~= "" and held ~= command then
        Say(pretty .. " was on " .. ns.CommandName(held) .. ".")
    end

    local ok, displaced = ns.AssignBinding(binding, command)
    if ok then
        Say(pretty .. " -> " .. name)
    else
        Say(tostring(displaced))
    end

    if ns.Refresh then ns.Refresh() end
end

----------------------------------------------------------------------
-- The mode
----------------------------------------------------------------------
local function Build()
    frame = CreateFrame("Frame", "DaylightKeymapHoverBind", UIParent)
    frame:SetAllPoints(UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:EnableMouse(false)          -- the mouse must reach the bars
    frame:EnableKeyboard(false)
    frame:EnableMouseWheel(true)
    frame:Hide()

    frame:SetScript("OnKeyDown", function(_, keyName) Take(keyName) end)
    frame:SetScript("OnMouseWheel", function(_, delta)
        Take(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
    end)
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.since = (self.since or 0) + elapsed
        if self.since < 0.1 then return end
        self.since = 0
        Light((HoveredButton()))
    end)

    banner = CreateFrame("Frame", nil, UIParent)
    banner:SetSize(460, 64)
    banner:SetPoint("TOP", 0, -140)
    banner:SetFrameStrata("FULLSCREEN_DIALOG")
    API.Skin(banner, { window = true })
    banner:Hide()

    banner.title = API.Text(banner, "head", "LEFT")
    banner.title:SetPoint("TOPLEFT", 16, -12)
    banner.title:SetText("Bind on hover")

    banner.help = API.Text(banner, "small", "LEFT")
    banner.help:SetPoint("TOPLEFT", 16, -36)
    banner.help:SetWidth(428)
    banner.help:SetText("Point at an action bar button and press the combo you want. Escape to stop.")
    banner.help:SetTextColor(0.6, 0.66, 0.75)

    local watch = CreateFrame("Frame")
    watch:RegisterEvent("PLAYER_REGEN_DISABLED")
    watch:SetScript("OnEvent", function()
        if active then
            Say("Combat. Bind on hover is off.")
            ns.StopHoverBind()
        end
    end)
end

function ns.StartHoverBind()
    local ok, why = ns.CanEdit()
    if not ok then Say(why); return end

    if not frame then Build() end
    active = true
    frame:Show()
    frame:EnableKeyboard(true)
    frame:SetPropagateKeyboardInput(false)
    banner:Show()
    Say("Bind on hover is on. Point at a button, press a combo. Escape to stop.")
    if ns.SetHoverBindButton then ns.SetHoverBindButton(true) end
end

function ns.StopHoverBind()
    if not frame then return end
    active = false
    Light(nil)
    frame:EnableKeyboard(false)
    frame:Hide()
    banner:Hide()
    if ns.IsDirty() then ns.Save() end
    Say("Bind on hover is off.")
    if ns.SetHoverBindButton then ns.SetHoverBindButton(false) end
end

function ns.ToggleHoverBind()
    if active then ns.StopHoverBind() else ns.StartHoverBind() end
end

function ns.HoverBindActive() return active end

my.RegisterCommand("bindhover", function()
    ns.ToggleHoverBind()
end, "Point at an action bar button and press a combo to bind it")
