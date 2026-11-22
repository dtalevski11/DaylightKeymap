-- DaylightKeymap
-- Panel.lua — the map itself.

local ADDON, ns = ...
local API, my = ns.API, ns.my

local U, PAD = 32, 4           -- one key unit, and the gap between keys
local PITCH = U + PAD
local ART = "Interface\\AddOns\\DaylightKeymap\\"

----------------------------------------------------------------------
-- Palette. Fills of our own, because API.Colors() covers text. The
-- accent is borrowed for selection so the map follows the player's.
----------------------------------------------------------------------
-- Five steps along the Daylight UI sunset: deep blue for a key with
-- nothing on it, warming through to amber for one that is full.
local HUE = {
    [0] = { 0x48 / 255, 0x56 / 255, 0xA5 / 255 },   -- #4856A5 unassigned
    [1] = { 0x96 / 255, 0x54 / 255, 0xA4 / 255 },   -- #9654A4 one
    [2] = { 0xE2 / 255, 0x5F / 255, 0x70 / 255 },   -- #E25F70 two
    [3] = { 0xF0 / 255, 0x80 / 255, 0x48 / 255 },   -- #F08048 three
    [4] = { 0xF6 / 255, 0xAC / 255, 0x48 / 255 },   -- #F6AC48 four or more
}
ns.HUE = HUE

local FILL, EDGE, TEXT = {}, {}, {}
for i = 0, 4 do
    local c = HUE[i]
    FILL[i] = { c[1] * 0.20 + 0.035, c[2] * 0.20 + 0.040, c[3] * 0.20 + 0.055 }
    EDGE[i] = { c[1] * 0.70,         c[2] * 0.70,         c[3] * 0.70 }
    TEXT[i] = { c[1] * 0.45 + 0.52,  c[2] * 0.45 + 0.50,  c[3] * 0.45 + 0.50 }
end
ns.FILL, ns.EDGE, ns.TEXT = FILL, EDGE, TEXT

-- Free keys when the free-only filter is on: the unassigned hue, lit up.
local FREE_FILL = { 0.075, 0.090, 0.180 }
local FREE_EDGE = { 0.420, 0.490, 0.880 }
local FREE_TEXT = { 0.690, 0.740, 0.980 }

-- Keys the game will not let you bind at all: the modifiers, and the ones
-- the operating system or the keyboard itself swallows. Grey, so they read
-- as structure rather than as somewhere with room left.
local MOD_FILL = { 0.086, 0.090, 0.098 }
local MOD_EDGE = { 0.224, 0.235, 0.251 }
local MOD_TEXT = { 0.408, 0.427, 0.455 }
ns.MOD_FILL, ns.MOD_EDGE, ns.MOD_TEXT = MOD_FILL, MOD_EDGE, MOD_TEXT

local function Bucket(n)
    if n <= 0 then return 0 end
    if n >= 4 then return 4 end
    return n
end
ns.Bucket = Bucket

----------------------------------------------------------------------
-- A plain bordered tile
----------------------------------------------------------------------
local function MakeTile(parent)
    local f = CreateFrame("Button", nil, parent)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()

    f.edges = {}
    for i = 1, 4 do f.edges[i] = f:CreateTexture(nil, "BORDER") end
    local top, right, bottom, left = unpack(f.edges)
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(1)
    bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT"); bottom:SetHeight(1)
    left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(1)
    right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); right:SetWidth(1)

    f.label = API.Text(f, "small")
    f.label:SetPoint("CENTER")

    f.count = API.Text(f, "tiny")
    f.count:SetPoint("TOPRIGHT", -3, -2)

    -- Selection is an outline, not a fill, so it never hides what the key
    -- is or flattens a shape that isn't a rectangle.
    f.selEdges = {}
    for i = 1, 4 do
        local t = f:CreateTexture(nil, "OVERLAY")
        t:Hide()
        f.selEdges[i] = t
    end
    local st, sr, sb, sl = unpack(f.selEdges)
    st:SetPoint("TOPLEFT", -2, 2);     st:SetPoint("TOPRIGHT", 2, 2);      st:SetHeight(2)
    sb:SetPoint("BOTTOMLEFT", -2, -2); sb:SetPoint("BOTTOMRIGHT", 2, -2);  sb:SetHeight(2)
    sl:SetPoint("TOPLEFT", -2, 2);     sl:SetPoint("BOTTOMLEFT", -2, -2);  sl:SetWidth(2)
    sr:SetPoint("TOPRIGHT", 2, 2);     sr:SetPoint("BOTTOMRIGHT", 2, -2);  sr:SetWidth(2)

    function f:ShowSel(on, r, g, b)
        for _, edge in ipairs(self.selEdges) do
            edge:SetShown(on)
            if on then edge:SetColorTexture(r, g, b) end
        end
    end

    function f:Paint(bucket)
        self.bg:SetColorTexture(unpack(FILL[bucket]))
        local e = EDGE[bucket]
        for _, edge in ipairs(self.edges) do edge:SetColorTexture(e[1], e[2], e[3]) end
        self.label:SetTextColor(unpack(TEXT[bucket]))
        self.count:SetTextColor(unpack(TEXT[bucket]))
    end

    function f:PaintModifier()
        self.bg:SetColorTexture(unpack(MOD_FILL))
        for _, edge in ipairs(self.edges) do edge:SetColorTexture(unpack(MOD_EDGE)) end
        self.label:SetTextColor(unpack(MOD_TEXT))
        self.count:SetText("")
    end

    return f
end

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local panel, keyTiles, mouseBits, selected
local listening   -- moving a binding: { command, fromKey, fromLayer }
local armed       -- a free slot waiting for a command: { key, layer }
local layerFilter = "all"
local freeOnly = false
local searchText = ""

local function Selected() return selected end
local function Say(msg) print(ns.TAG .. msg) end

----------------------------------------------------------------------
-- Remember which action bar button a drag came from.
--
-- FrameMade is sent for buttons that already exist the moment we start
-- listening, and the bars are built before any plugin loads, so this
-- catches every one of them. HookScript only adds to the button's own
-- OnDragStart; it does not touch any of the game's protected calls.
----------------------------------------------------------------------
my.On("FrameMade", function(kind, frame)
    if kind ~= "actionbutton" or not frame or frame.dkmHooked then return end
    frame.dkmHooked = true
    pcall(frame.HookScript, frame, "OnDragStart", function(self)
        ns.NoteDragSource(self)
    end)
end)

----------------------------------------------------------------------
-- Shared key behaviour
----------------------------------------------------------------------
local function KeyTooltip(self)
    if not self.keyName then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.keyName, 1, 1, 1)
    local slots = ns.map and ns.map[self.keyName]
    local any = false
    for _, layer in ipairs(ns.Layers()) do
        local slot = slots and slots[layer]
        if slot then
            any = true
            GameTooltip:AddDoubleLine(ns.LayerLabel(layer), slot.name, 0.6, 0.66, 0.75, 1, 1, 1)
        end
    end
    if not any then GameTooltip:AddLine("Free on every layer shown.", 0.5, 0.84, 0.6) end
    local hidden = ns.HiddenCountFor(self.keyName)
    if hidden > 0 then
        GameTooltip:AddLine(hidden .. " more on layers not shown.", 0.91, 0.76, 0.37)
    end
    GameTooltip:Show()
end

-- Why a greyed key is greyed. Dead to the click, but it can still say why.
local MOD_WHY = {
    Ctrl  = "A modifier. It changes what another key does rather than doing anything on its own.",
    Shift = "A modifier. It changes what another key does rather than doing anything on its own.",
    Alt   = "A modifier. It changes what another key does rather than doing anything on its own.",
    Win   = "Windows takes this before the game ever sees it.",
    Fn    = "The keyboard handles this itself. It never reaches the computer, let alone the game.",
    Menu  = "WoW has no name for this key, so there is nothing to bind to.",
}

local function ModTooltip(self)
    local why = MOD_WHY[self.label and self.label:GetText()]
    if not why then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.label:GetText(), 1, 1, 1)
    GameTooltip:AddLine(why, 0.6, 0.66, 0.75, true)
    GameTooltip:Show()
end

local function OnKeyClick(self)
    -- clicking the key that is already picked puts it back down
    if selected == self.keyName then
        selected = nil
        armed = nil
    else
        selected = self.keyName
    end
    ns.Refresh()
end

local function OnKeyDrop(self)
    local command, name = ns.CommandOnCursor()
    if not command then
        if GetCursorInfo() then
            Say("That did not come off one of Daylight UI's action bars, so there is no button to bind. Pick the key and use the search instead.")
        end
        return
    end
    local layer = (layerFilter ~= "all") and layerFilter or ns.CurrentLayer()
    local ok, info = ns.Assign(self.keyName, layer, command)
    ClearCursor()
    ns.ForgetDragSource()
    if ok then
        selected = self.keyName
        Say(ns.Compose(self.keyName, layer) .. " -> " .. name)
        if info then Say("Took it from " .. ns.CommandName(info) .. ".") end
    else
        Say(tostring(info))
    end
    ns.Refresh()
end

local function WireKey(tile, keyName)
    tile.keyName = keyName
    tile:SetScript("OnEnter", KeyTooltip)
    tile:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tile:SetScript("OnClick", OnKeyClick)
    tile:RegisterForDrag("LeftButton")
    tile:SetScript("OnReceiveDrag", OnKeyDrop)
    tile:SetScript("OnMouseUp", function(self)
        if GetCursorInfo() then OnKeyDrop(self) end
    end)
end

----------------------------------------------------------------------
-- Board
----------------------------------------------------------------------
local function LayoutBoard(host)
    for _, t in ipairs(keyTiles or {}) do t:Hide(); t:SetParent(nil) end
    keyTiles = {}

    local places, rowCount, width, overflow = ns.BuildBoard()

    for _, p in ipairs(places) do
        local tile = MakeTile(host)
        tile.label:SetText(p.label)
        tile:SetSize(p.w * PITCH - PAD, U)
        tile:SetPoint("TOPLEFT", host, "TOPLEFT", p.x * PITCH, -p.y * PITCH)

        if p.mod then
            tile:PaintModifier()
            tile:SetScript("OnEnter", ModTooltip)
            tile:SetScript("OnLeave", function() GameTooltip:Hide() end)
        else
            WireKey(tile, p.key)
        end
        keyTiles[#keyTiles + 1] = tile
    end

    local y = rowCount * PITCH

    if overflow then
        y = y + 12
        local cap = API.Text(host, "tiny", "LEFT")
        cap:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -y)
        cap:SetText("NO CAP ON A 60% BOARD - STILL BINDABLE")
        cap:SetTextColor(0.31, 0.34, 0.40)
        y = y + 20

        local x = 0
        for _, entry in ipairs(overflow) do
            local tile = MakeTile(host)
            tile.label:SetText(entry.label)
            tile:SetSize(PITCH + 10, U - 6)
            tile:SetPoint("TOPLEFT", host, "TOPLEFT", x, -y)
            WireKey(tile, entry.key)
            keyTiles[#keyTiles + 1] = tile
            x = x + PITCH + 14
            if x > 13 * PITCH then x = 0; y = y + U end
        end
        y = y + U
    end

    host:SetSize(width * PITCH, y)
    return y
end

----------------------------------------------------------------------
-- Mouse
----------------------------------------------------------------------
local MOUSE_W, MOUSE_H = 112, 168

-- where each part's hit area sits, as fractions of the mouse frame
local REGION = {
    left  = { 0.00, 0.00, 0.42, 0.41 },
    right = { 0.58, 0.00, 1.00, 0.41 },
    wheel = { 0.42, 0.04, 0.58, 0.34 },
}

local function LayoutMouse(host)
    for _, b in ipairs(mouseBits or {}) do b:Hide(); b:SetParent(nil) end
    mouseBits = {}

    local core, left, right = ns.BuildMouse()

    -- Thumb buttons as squares in two columns: M4 M5 / M6 M7 / ... so a
    -- twelve-button mouse stays beside the drawing instead of running down
    -- the panel and over the legend.
    local SQ, SQ_GAP = 38, 4
    local SQ_PITCH = SQ + SQ_GAP
    local thumbW = (#left > 0) and (SQ_PITCH * 2 - SQ_GAP) or 0
    local thumbRows = math.ceil(#left / 2)

    for i, entry in ipairs(left) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local tile = MakeTile(host)
        tile:SetSize(SQ, SQ)
        tile:SetPoint("TOPLEFT", host, "TOPLEFT", col * SQ_PITCH, -row * SQ_PITCH)
        tile.label:SetText(entry.label)
        WireKey(tile, entry.key)
        mouseBits[#mouseBits + 1] = tile
    end

    local gutter = (thumbW > 0) and (thumbW + 16) or 0

    -- the mouse itself
    local body = CreateFrame("Frame", nil, host)
    body:SetSize(MOUSE_W, MOUSE_H)
    body:SetPoint("TOPLEFT", host, "TOPLEFT", gutter, 0)
    mouseBits[#mouseBits + 1] = body

    local shell = body:CreateTexture(nil, "BACKGROUND")
    shell:SetAllPoints()
    shell:SetTexture(ART .. "mouse-body.png")
    shell:SetVertexColor(unpack(FILL[0]))

    for _, entry in ipairs(core) do
        local tex = body:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture(ART .. "mouse-" .. entry.part .. ".png")

        local r = REGION[entry.part]
        local hit = CreateFrame("Button", nil, body)
        hit:SetPoint("TOPLEFT", body, "TOPLEFT", r[1] * MOUSE_W, -r[2] * MOUSE_H)
        hit:SetPoint("BOTTOMRIGHT", body, "TOPLEFT", r[3] * MOUSE_W, -r[4] * MOUSE_H)
        hit.tex = tex

        hit.count = API.Text(hit, "tiny")
        if entry.part == "wheel" then
            -- Centred over the wheel but raised to the top of the mouse:
            -- the strip itself is 16px, far too narrow to hold a label, and
            -- LMB and RMB sit lower so nothing collides.
            hit.count:SetPoint("TOP", body, "TOP", 0, -5)
        else
            hit.count:SetPoint("CENTER", 0, -6)
        end

        function hit:Paint(bucket)
            if self.locked then
                self.tex:SetVertexColor(unpack(MOD_FILL))
                self.count:SetTextColor(unpack(MOD_TEXT))
                return
            end
            self.tex:SetVertexColor(unpack(FILL[bucket]))
            self.count:SetTextColor(unpack(TEXT[bucket]))
        end

        -- A mouse button is not a rectangle, so it lights up by tinting its
        -- own shape rather than having a box drawn over it.
        function hit:ShowSel(on, r, g, b)
            if on then
                self.tex:SetVertexColor(r, g, b)
                self.count:SetTextColor(r, g, b)
            end
        end

        hit.mouseLabel = entry.label
        hit.keyName = entry.key     -- so the repaint loop still reaches it

        if entry.locked then
            -- Dead to the touch, like the modifier keys. Nothing can be put
            -- here, so offering a click would only suggest otherwise. The
            -- tooltip explains, and /dui keymapfix is the way back if one
            -- has been knocked off the game's own action.
            hit.locked = true
            hit.keyName = entry.key
            hit:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(self.mouseLabel, 1, 1, 1)
                GameTooltip:AddLine("Reserved. The game uses this for looking, moving and selecting, so nothing else can take it.", 0.6, 0.66, 0.75, true)

                local default = ns.ReservedDefault(self.keyName)
                local now = GetBindingAction(self.keyName)

                if default and now ~= default then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("This is not doing its usual job:", 0.94, 0.54, 0.54)
                    GameTooltip:AddLine(now ~= "" and ns.CommandName(now) or "nothing at all", 1, 1, 1)
                    GameTooltip:AddLine("Type /dui keymapfix to put the game's own action back.", 0.42, 0.46, 0.52, true)
                else
                    GameTooltip:AddLine("Mouse 3 and up bind normally.", 0.42, 0.46, 0.52, true)
                end
                GameTooltip:Show()
            end)
            hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
        else
            WireKey(hit, entry.key)
        end

        mouseBits[#mouseBits + 1] = hit
    end

    -- wheel directions, on the right
    for i, entry in ipairs(right) do
        local tile = MakeTile(host)
        tile:SetSize(88, 26)
        tile:SetPoint("TOPLEFT", host, "TOPLEFT", gutter + MOUSE_W + 16, -(i - 1) * 30)
        tile.label:SetText(entry.label)
        WireKey(tile, entry.key)
        mouseBits[#mouseBits + 1] = tile
    end

    host:SetSize(gutter + MOUSE_W + 16 + 88,
        math.max(MOUSE_H, thumbRows * SQ_PITCH - SQ_GAP))
end

----------------------------------------------------------------------
-- Slots
----------------------------------------------------------------------
local slotRows = {}

local function StopListening()
    if listening then
        listening = nil
        panel.capture:Hide()
        panel.capture:EnableKeyboard(false)
    end
end

local function BeginMove(key, layer, command)
    local ok, why = ns.CanEdit()
    if not ok then Say(why); return end
    armed = nil
    listening = { command = command, fromKey = key, fromLayer = layer }
    panel.capture:Show()
    panel.capture:EnableKeyboard(true)
    panel.capture:SetPropagateKeyboardInput(false)
    ns.Refresh()
end

local function ArmSlot(key, layer)
    StopListening()
    if armed and armed.key == key and armed.layer == layer then
        armed = nil
    else
        armed = { key = key, layer = layer }
    end
    ns.Refresh()
end

local function BuildSlotRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(28)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()

    row.mk = API.Text(row, "tiny", "LEFT")
    row.mk:SetPoint("LEFT", 8, 0)
    row.mk:SetWidth(78)

    row.act = API.Text(row, "small", "LEFT")
    row.act:SetPoint("LEFT", 92, 0)
    row.act:SetPoint("RIGHT", -34, 0)

    -- A real button, so clearing one binding is a single obvious click
    -- rather than a right-click you had to be told about.
    local clear = CreateFrame("Button", nil, row)
    clear:SetSize(24, 24)
    clear:SetPoint("RIGHT", -5, 0)
    clear:SetFrameLevel(row:GetFrameLevel() + 2)

    clear.bg = clear:CreateTexture(nil, "BACKGROUND")
    clear.bg:SetAllPoints()
    clear.bg:SetColorTexture(0, 0, 0, 0)

    clear.mark = API.Text(clear, "small")
    clear.mark:SetPoint("CENTER")

    clear:SetScript("OnClick", function(self)
        local r = self:GetParent()
        if not r.layer then return end
        if r.bound then
            ns.Clear(r.key, r.layer)
            ns.Refresh()
        else
            ArmSlot(r.key, r.layer)
        end
    end)
    clear:SetScript("OnEnter", function(self)
        local r = self:GetParent()
        if not r.layer then return end
        self.bg:SetColorTexture(r.bound and 0.45 or 0.18, r.bound and 0.13 or 0.34, r.bound and 0.13 or 0.22, 1)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if r.bound then
            GameTooltip:AddLine("Clear this binding", 0.94, 0.54, 0.54)
            GameTooltip:AddLine(ns.Compose(r.key, r.layer) .. " becomes free.", 0.6, 0.66, 0.75)
        else
            GameTooltip:AddLine("Assign this slot", 0.5, 0.84, 0.6)
            GameTooltip:AddLine("Then pick an action from the list.", 0.6, 0.66, 0.75)
        end
        GameTooltip:Show()
    end)
    clear:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0, 0, 0, 0)
        GameTooltip:Hide()
    end)
    row.clear = clear

    -- Left-click arms the slot whether or not something is on it: pick it,
    -- then click a command on the right and it lands here. Right-click on a
    -- taken slot picks the binding up to move it to another key instead.
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if not self.layer then return end
        if button == "RightButton" and self.bound then
            BeginMove(self.key, self.layer, self.command)
        else
            ArmSlot(self.key, self.layer)
        end
    end)

    row:SetScript("OnEnter", function(self)
        if not self.layer then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(ns.Compose(self.key, self.layer), 1, 1, 1)
        if self.bound then
            GameTooltip:AddLine("Left-click, then pick an action to replace it.", 0.6, 0.66, 0.75)
            GameTooltip:AddLine("Right-click: move this binding to another key.", 0.6, 0.66, 0.75)
            GameTooltip:AddLine("The x on the right clears it.", 0.6, 0.66, 0.75)
        else
            GameTooltip:AddLine("Free slot", 0.42, 0.49, 0.88)
            GameTooltip:AddLine("Left-click, then pick an action from the list.", 0.6, 0.66, 0.75)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

local function RefreshSlots()
    local key = Selected()
    local layers = ns.Layers()

    for _, row in ipairs(slotRows) do row:Hide() end

    if not key then
        panel.selKey:SetText("-")
        panel.selKey:SetTextColor(0.37, 0.41, 0.47)
        panel.selTitle:SetText("No key picked")
        panel.selSub:SetText("Click a key on the map.")
        return
    end

    panel.slotHost:SetHeight(#layers * 31)

    local used = ns.CountFor(key)
    local short = ns.ShortKeyName(key)
    panel.selKey:SetText(short)
    panel.selKey:SetTextColor(unpack(TEXT[Bucket(used)]))
    -- only worth repeating when the tile had to shorten it
    panel.selTitle:SetText(short ~= key and key or "")
    panel.selSub:SetText(used .. " of " .. #layers .. " layers used, "
        .. (#layers - used) .. " free")

    local slots = ns.map and ns.map[key] or {}

    for i, layer in ipairs(layers) do
        local row = slotRows[i]
        if not row then
            row = BuildSlotRow(panel.slotHost)
            slotRows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel.slotHost, "TOPLEFT", 0, -(i - 1) * 31)
        row:SetPoint("TOPRIGHT", panel.slotHost, "TOPRIGHT", 0, -(i - 1) * 31)

        row.key, row.layer = key, layer
        row.mk:SetText(ns.ModShort(layer))

        local slot = slots[layer]
        row.command = slot and slot.command or nil
        row.bound = (slot ~= nil)

        local moving = listening and listening.fromKey == key and listening.fromLayer == layer
        local waiting = armed and armed.key == key and armed.layer == layer
        local mark = row.clear.mark

        if moving then
            row.bg:SetColorTexture(0.133, 0.110, 0.063)
            row.act:SetText("Press the new combo...")
            row.act:SetTextColor(API.Accent())
            mark:SetText("esc")
            mark:SetTextColor(0.37, 0.41, 0.47)
        elseif waiting then
            row.bg:SetColorTexture(0.133, 0.110, 0.063)
            row.act:SetText(slot and ("Pick an action to replace " .. slot.name)
                                  or "Pick an action from the list...")
            row.act:SetTextColor(API.Accent())
            mark:SetText("esc")
            mark:SetTextColor(0.37, 0.41, 0.47)
        elseif slot then
            row.bg:SetColorTexture(0.086, 0.102, 0.129)
            row.act:SetText(slot.name)
            row.act:SetTextColor(0.847, 0.867, 0.902)
            mark:SetText("x")
            mark:SetTextColor(0.62, 0.40, 0.40)
        else
            row.bg:SetColorTexture(unpack(FILL[0]))
            row.act:SetText("unassigned")
            row.act:SetTextColor(unpack(TEXT[0]))
            mark:SetText("+")
            mark:SetTextColor(unpack(TEXT[0]))
        end
        row:Show()
    end
end

----------------------------------------------------------------------
-- Command search
----------------------------------------------------------------------
local resultRows, resultOffset = {}, 0
local browseOpen = {}

-- Daylight builds its buttons with their own label, so the frame's own
-- SetText does not touch what you actually read. Find the label wherever it
-- lives rather than guessing at one name.
local function SetButtonLabel(btn, text)
    if not btn then return end
    for _, key in ipairs({ "text", "Text", "label", "Label", "title" }) do
        local fs = btn[key]
        if type(fs) == "table" and fs.SetText then fs:SetText(text); return end
    end
    if btn.GetFontString then
        local fs = btn:GetFontString()
        if fs then fs:SetText(text); return end
    end
    if btn.GetRegions then
        for _, region in ipairs({ btn:GetRegions() }) do
            if region.GetObjectType and region:GetObjectType() == "FontString" then
                region:SetText(text); return
            end
        end
    end
    if btn.SetText then btn:SetText(text) end
end

-- True when every heading in the list is already open.
local function AllGroupsOpen()
    local groups = ns.CommandGroups()
    if not groups or #groups == 0 then return false end
    for _, group in ipairs(groups) do
        if not browseOpen[group.name] then return false end
    end
    return true
end

-- The actions list is always there; this is what it is narrowed to.
local FILTERS = {
    { key = "all",    label = "All actions",
      tip = "Every action, under the same headings the keybindings window uses. Click a heading to open it." },
    { key = "double", label = "On two keys",
      tip = "Only actions reachable from two different keys. Two is WoW's limit, so this is every action with more than one." },
    { key = "none",   label = "Not bound",
      tip = "Only actions with no key at all." },
}
local filterIndex = 1

local function FilterKey() return FILTERS[filterIndex].key end

local function PassesFilter(entry)
    local mode = FilterKey()
    if mode == "all" then return true end
    local first, second = ns.KeysForCommand(entry.command)
    if mode == "double" then return second ~= nil end
    return first == nil
end
local resultCount, resultTotal = 8, 0   -- rows that fit, matches found
local ROW_H = 28

-- What the list below the search box is showing: matches while you type,
-- or every action under its own heading once you press See all.
local function Matches()
    local out = {}

    if searchText ~= "" then
        local needle = searchText:lower()
        for _, entry in ipairs(ns.commands or {}) do
            if (entry.name:lower():find(needle, 1, true)
                or entry.category:lower():find(needle, 1, true))
                and PassesFilter(entry) then
                out[#out + 1] = { kind = "action", entry = entry }
                if #out >= 200 then break end
            end
        end
        return out
    end

    for _, group in ipairs(ns.CommandGroups()) do
        local kept = {}
        for _, entry in ipairs(group.items) do
            if PassesFilter(entry) then kept[#kept + 1] = entry end
        end

        if #kept > 0 then
            -- a filter opens what it found, so matches are not buried
            local open = browseOpen[group.name] or (FilterKey() ~= "all")
            out[#out + 1] = {
                kind = "header", name = group.name,
                count = #kept, open = open,
            }
            if open then
                for _, entry in ipairs(kept) do
                    out[#out + 1] = { kind = "action", entry = entry }
                end
            end
        end
    end
    return out
end

-- Scrollbar: a dark track with a thumb sized to how much of the list you
-- can see, draggable, and hidden entirely when everything already fits.
local function RefreshScrollbar()
    local bar = panel.scrollbar
    if not bar then return end

    local overflow = math.max(0, resultTotal - resultCount)
    bar:SetShown(panel.results:IsShown() and overflow > 0)
    if not bar:IsShown() then return end

    local trackH = bar:GetHeight()
    local frac = resultCount / resultTotal
    local thumbH = math.max(24, math.floor(trackH * frac))
    local travel = trackH - thumbH
    local pos = (overflow > 0) and (resultOffset / overflow) or 0

    bar.thumb:SetHeight(thumbH)
    bar.thumb:SetPoint("TOP", bar, "TOP", 0, -math.floor(travel * pos))
    bar.thumb.tex:SetColorTexture(API.Accent())
    bar.thumb.tex:SetAlpha(bar.thumb.held and 1 or 0.65)
end

local function RefreshResults()
    local list = Matches()
    resultTotal = #list
    resultOffset = math.max(0, math.min(resultOffset, math.max(0, resultTotal - resultCount)))

    panel.results:SetShown(resultTotal > 0)
    if panel.resultsHead then
        panel.resultsHead:SetShown(resultTotal > 0)
        if searchText ~= "" then
            panel.resultsHead:SetText("MATCHING ACTIONS (" .. resultTotal .. ")")
        else
            panel.resultsHead:SetText(FILTERS[filterIndex].label:upper()
                .. " (" .. resultTotal .. " lines)")
        end
    end

    -- Headings only exist when you are browsing everything: a search is a
    -- flat list, and the other two filters open what little they find. The
    -- button has no job in either, so it steps out of the way.
    if panel.expandAll then
        local useful = (searchText == "" and FilterKey() == "all")
        panel.expandAll:SetShown(useful and resultTotal > 0)
        if useful then
            local open = AllGroupsOpen()
            SetButtonLabel(panel.expandAll, open and "Collapse all" or "Expand all")
            panel.expandAll:SetAlpha(open and 1 or 0.7)
        end
    end

    for i = 1, resultCount do
        local row = resultRows[i]
        if not row then
            row = CreateFrame("Button", nil, panel.results)
            row:SetHeight(26)
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(0.086, 0.102, 0.129)
            row.name = API.Text(row, "small", "LEFT")
            row.name:SetWordWrap(false)

            row.cat = API.Text(row, "tiny", "RIGHT")
            row.cat:SetPoint("RIGHT", -8, 0)
            row.cat:SetWordWrap(false)

            -- A tag saying what this command is already bound to, so you
            -- can see at a glance which actions still need a key.
            row.tag = CreateFrame("Frame", nil, row)
            row.tag:SetHeight(16)
            row.tag.bg = row.tag:CreateTexture(nil, "BACKGROUND")
            row.tag.bg:SetAllPoints()
            row.tag.text = API.Text(row.tag, "tiny")
            row.tag.text:SetPoint("CENTER")
            row.tag:Hide()

            -- Same gesture as the keybindings window: always there on an
            -- action that has keys, no hunting for a hover target.
            row.clear = CreateFrame("Button", nil, row)
            row.clear:SetSize(56, 20)
            row.clear:SetPoint("RIGHT", -6, 0)
            row.clear:SetFrameLevel(row:GetFrameLevel() + 2)
            row.clear.bg = row.clear:CreateTexture(nil, "BACKGROUND")
            row.clear.bg:SetAllPoints()
            row.clear.text = API.Text(row.clear, "tiny")
            row.clear.text:SetPoint("CENTER")
            row.clear.text:SetText("Clear all")
            row.clear:Hide()

            row.clear:SetScript("OnClick", function(self)
                local parent = self:GetParent()
                if not parent.command then return end
                local a, b = ns.KeysForCommand(parent.command)
                if a then ns.ClearBinding(a) end
                if b then ns.ClearBinding(b) end
                Say(parent.label .. ": cleared.")
                ns.Refresh()
            end)
            row.clear:SetScript("OnEnter", function(self)
                self.bg:SetColorTexture(0.45, 0.13, 0.13, 1)
                self.text:SetTextColor(1, 0.88, 0.88)
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:AddLine("Clear every key on this action", 0.94, 0.54, 0.54)
                GameTooltip:Show()
            end)
            row.clear:SetScript("OnLeave", function(self)
                self.bg:SetColorTexture(0.26, 0.10, 0.10, 1)
                self.text:SetTextColor(0.80, 0.52, 0.52)
                GameTooltip:Hide()
            end)
            row:SetPoint("TOPLEFT", panel.results, "TOPLEFT", 0, -(i - 1) * ROW_H)
            row:SetPoint("TOPRIGHT", panel.results, "TOPRIGHT", -12, -(i - 1) * ROW_H)

            -- The tag only has room for the first key and a count of the
            -- rest. Hovering the row spells every one of them out.
            row:SetScript("OnEnter", function(self)
                if self.headerName or not self.command then return end
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:AddLine(self.label, 1, 1, 1)

                local a, b = ns.KeysForCommand(self.command)
                if a then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("On:", 0.42, 0.46, 0.52)
                    GameTooltip:AddLine(ns.PrettyBinding(a), unpack(TEXT[1]))
                    if b then GameTooltip:AddLine(ns.PrettyBinding(b), unpack(TEXT[1])) end
                else
                    GameTooltip:AddLine("Not bound to anything.", unpack(TEXT[0]))
                end

                if self.source and self.source ~= "" then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("From " .. self.source, 0.42, 0.46, 0.52)
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row:SetScript("OnClick", function(self)
                if self.headerName then
                    browseOpen[self.headerName] = not browseOpen[self.headerName]
                    RefreshResults()
                    return
                end
                if not self.command then return end

                -- Nothing waiting on the map means you are working the other
                -- way round: this action, now press where you want it.
                if not armed and not Selected() then
                    ns.AwaitKeyFor(self.command, self.label)
                    return
                end

                local key, layer
                if armed then
                    key, layer = armed.key, armed.layer
                else
                    key = Selected()
                    layer = (layerFilter ~= "all") and layerFilter or ""
                    local slots = ns.map[key] or {}
                    if slots[layer] then
                        local found
                        for _, l in ipairs(ns.Layers()) do
                            if not slots[l] then found = l; break end
                        end
                        if not found then
                            Say("Every layer of " .. key .. " is taken. Clear one first.")
                            return
                        end
                        layer = found
                    end
                end

                armed = nil
                local ok, info = ns.Assign(key, layer, self.command)
                if ok then
                    Say(ns.Compose(key, layer) .. " -> " .. self.label)
                    if info then Say("Took it from " .. ns.CommandName(info) .. ".") end
                else
                    Say(tostring(info))
                end
                ns.Refresh()
            end)
            resultRows[i] = row
        end

        local item = list[i + resultOffset]

        if item and item.kind == "header" then
            row.headerName, row.command, row.label = item.name, nil, nil
            row.bg:SetColorTexture(0.133, 0.153, 0.196, 1)
            row.tag:Hide()
            row.clear:Hide()
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", row, "LEFT", 8, 0)
            row.name:SetPoint("RIGHT", row.cat, "LEFT", -8, 0)
            row.name:SetText((item.open and "- " or "+ ") .. item.name)
            row.name:SetTextColor(0.90, 0.92, 0.95)
            row.cat:SetText(tostring(item.count))
            row.cat:SetTextColor(0.42, 0.46, 0.52)
            row:Show()

        elseif item then
            local entry = item.entry
            row.headerName = nil
            row.bg:SetColorTexture(0.086, 0.102, 0.129, 1)
            row.command, row.label = entry.command, entry.name
            row.name:SetText(entry.name)
            row.name:SetTextColor(0.847, 0.867, 0.902)

            -- The source is only worth saying when it is not the game's own.
            local fromAddon = ns.IsAddonCategory(entry.category)
            row.source = fromAddon and entry.category or nil
            row.cat:SetText("")

            local first, second = ns.KeysForCommand(entry.command)

            row.clear:SetShown(first ~= nil)
            row.clear.bg:SetColorTexture(0.26, 0.10, 0.10, 1)
            row.clear.text:SetTextColor(0.80, 0.52, 0.52)
            local label = ns.PrettyBinding(first)
            if label and second then label = label .. "  +1" end

            if label then
                row.tag.text:SetText(label)
                row.tag.text:SetTextColor(unpack(TEXT[1]))
                row.tag.bg:SetColorTexture(FILL[1][1], FILL[1][2], FILL[1][3], 1)
                row.tag:SetWidth(row.tag.text:GetStringWidth() + 14)
                row.tag:ClearAllPoints()
                row.tag:SetPoint("RIGHT", first and row.clear or row.cat, "LEFT", -8, 0)
                row.tag:Show()
            else
                row.tag:Hide()
            end

            -- The name stops where the tag or the source starts, so a long
            -- action is cut short instead of running underneath them.
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", row, "LEFT", searchText == "" and 22 or 8, 0)
            if row.tag:IsShown() then
                row.name:SetPoint("RIGHT", row.tag, "LEFT", -8, 0)
            elseif row.clear:IsShown() then
                row.name:SetPoint("RIGHT", row.clear, "LEFT", -8, 0)
            else
                row.name:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            end

            row:Show()
        else
            row:Hide()
        end
    end

    RefreshScrollbar()
end

----------------------------------------------------------------------
-- Refresh
----------------------------------------------------------------------
function ns.Refresh()
    if not panel or not panel:IsShown() then return end
    ns.Scan()

    local showing = {}
    if layerFilter == "all" then
        for _, l in ipairs(ns.Layers()) do showing[l] = true end
    else
        showing[layerFilter] = true
    end

    local function paint(tile)
        if not tile.keyName or not tile.Paint then return end
        local slots = ns.map[tile.keyName]
        local n = 0
        if slots then
            for layer in pairs(showing) do
                if slots[layer] then n = n + 1 end
            end
        end
        tile:Paint(Bucket(n))

        local showCount = ns.Get("showCounts") and n > 0
        if tile.mouseLabel then
            tile.count:SetText(showCount and (tile.mouseLabel .. " " .. n) or tile.mouseLabel)
        else
            tile.count:SetText(showCount and tostring(n) or "")
        end

        if tile.locked then
            tile:SetAlpha(freeOnly and 0.12 or 1)
        elseif freeOnly then
            -- The point of this filter is to find free keys, so they get
            -- lit up rather than dimmed. Taken keys drop right back.
            if n == 0 then
                tile:SetAlpha(1)
                if tile.edges then
                    for _, edge in ipairs(tile.edges) do
                        edge:SetColorTexture(unpack(FREE_EDGE))
                    end
                    tile.bg:SetColorTexture(unpack(FREE_FILL))
                end
                if tile.tex then tile.tex:SetVertexColor(unpack(FREE_FILL)) end
                if tile.label then tile.label:SetTextColor(unpack(FREE_TEXT)) end
                tile.count:SetTextColor(unpack(FREE_TEXT))
            else
                tile:SetAlpha(0.12)
            end
        else
            tile:SetAlpha((n == 0 and ns.Get("dimUnbound")) and 0.8 or 1)
        end

        -- last, so it survives whatever the filter did to the colours
        if tile.ShowSel then
            tile:ShowSel(tile.keyName == Selected(), API.Accent())
        end
    end

    for _, t in ipairs(keyTiles or {}) do paint(t) end
    for _, t in ipairs(mouseBits or {}) do paint(t) end

    local bound, freeKeys, freeSlots = ns.Totals()
    panel.statBound:SetText(bound)
    panel.statKeys:SetText(freeKeys)
    panel.statSlots:SetText(freeSlots)

    local actionsBound, actionsTotal = ns.ActionTotals()
    panel.statActions:SetText(actionsBound .. " / " .. actionsTotal)
    panel.statDoubles:SetText(ns.DoubleBoundCount())

    RefreshSlots()
    RefreshResults()

    panel.combat:SetShown(InCombatLockdown())
    panel.discard:SetAlpha(ns.IsDirty() and 1 or 0.4)
    panel.save:SetAlpha(ns.IsDirty() and 1 or 0.4)
end

function ns.Restyle()
    if panel then ns.Refresh() end
end

----------------------------------------------------------------------
-- Binding an action by pressing the key you want it on
----------------------------------------------------------------------
local awaiting

function ns.AwaitKeyFor(command, name)
    local ok, why = ns.CanEdit()
    if not ok then Say(why); return end
    if not panel then return end

    awaiting = { command = command, name = name }
    panel.await.title:SetText(name)

    local a, b = ns.KeysForCommand(command)
    local now = ns.PrettyBinding(a)
    if now and b then now = now .. ", " .. (ns.PrettyBinding(b) or "") end
    panel.await.now:SetText(now and ("Currently on " .. now) or "Not bound yet")
    local tint = now and TEXT[1] or TEXT[0]
    panel.await.now:SetTextColor(tint[1], tint[2], tint[3])

    panel.await:Show()
    panel.await:Raise()
    panel.await:EnableKeyboard(true)
    panel.await:SetPropagateKeyboardInput(false)
end

local function StopAwaiting()
    awaiting = nil
    if not panel then return end
    panel.await:Hide()
    panel.await:EnableKeyboard(false)
end

----------------------------------------------------------------------
-- Build
----------------------------------------------------------------------
local function Build()
    panel = CreateFrame("Frame", "DaylightKeymapPanel", UIParent)
    -- The anchor is made once and never thrown away. A mover can only be
    -- registered under a key one time, and the panel inside is rebuilt
    -- whenever the board layout changes, so the mover has to be attached to
    -- something that outlives those rebuilds.
    if not ns.anchor then
        local a = CreateFrame("Frame", "DaylightKeymapAnchor", UIParent)
        a:SetSize(1280, 700)
        a:SetPoint("CENTER")
        a:SetFrameStrata("DIALOG")
        a:SetMovable(true)
        a:SetClampedToScreen(true)
        a:Hide()
        pcall(my.RegisterMover, a, "panel", ns.LABEL, { "CENTER", nil, "CENTER", 0, 0 })
        ns.anchor = a
    end

    panel:SetParent(ns.anchor)
    panel:SetAllPoints(ns.anchor)
    -- DIALOG so it opens above the Daylight UI options window, since the
    -- button on the options page is one of the ways in.
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    API.Skin(panel, { window = true })


    -- Drag it by the title bar. The Daylight mover still owns the frame in
    -- unlock mode; a manual drag just tells it to stand aside until then.
    local handle = CreateFrame("Frame", nil, panel)
    handle:SetPoint("TOPLEFT", 0, 0)
    handle:SetPoint("TOPRIGHT", -110, 0)
    handle:SetHeight(46)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        ns.anchor:StartMoving()
    end)
    handle:SetScript("OnDragStop", function()
        ns.anchor:StopMovingOrSizing()
        if my.SuspendMover then my.SuspendMover("panel", true) end
    end)
    handle:SetScript("OnEnter", function()
        GameTooltip:SetOwner(handle, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Drag to move the keymap.", 0.6, 0.66, 0.75)
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local title = API.Text(panel, "title", "LEFT")
    title:SetPoint("TOPLEFT", 20, -16)
    title:SetText("Keymap")

    local close = API.Button(panel, "Close", 24)
    close:SetWidth(78)
    close:SetPoint("TOPRIGHT", -16, -14)
    close:SetScript("OnClick", function() ns.HidePanel() end)

    -- toolbar ---------------------------------------------------------
    local bar = CreateFrame("Frame", nil, panel)
    bar:SetPoint("TOPLEFT", 20, -56)
    bar:SetPoint("TOPRIGHT", -20, -56)
    bar:SetHeight(28)

    local lbl = API.Text(bar, "tiny", "LEFT")
    lbl:SetPoint("LEFT")
    lbl:SetText("LAYER")
    lbl:SetTextColor(0.42, 0.46, 0.52)

    local segs = {
        { "all", "All",    "Every layer at once. A key's colour counts all the bindings on it." },
        { "",    "No mod", "Only bindings you press with no modifier held." },
        { "S",   "Shift",  "Only Shift+key bindings." },
        { "C",   "Ctrl",   "Only Ctrl+key bindings." },
        { "A",   "Alt",    "Only Alt+key bindings." },
    }
    if ns.Get("allLayers") then
        segs[#segs + 1] = { "SC",  "S+C",   "Only Shift+Ctrl+key bindings." }
        segs[#segs + 1] = { "SA",  "S+A",   "Only Shift+Alt+key bindings." }
        segs[#segs + 1] = { "CA",  "C+A",   "Only Ctrl+Alt+key bindings." }
        segs[#segs + 1] = { "SCA", "S+C+A", "Only Shift+Ctrl+Alt+key bindings." }
    end

    local segButtons, x = {}, 48
    for _, seg in ipairs(segs) do
        local b = API.Button(bar, seg[2], 24)
        b:SetWidth(seg[1] == "all" and 46 or 64)
        b:SetPoint("LEFT", bar, "LEFT", x, 0)
        b.layer = seg[1]
        b:SetScript("OnClick", function()
            layerFilter = seg[1]
            for _, other in ipairs(segButtons) do
                other:SetAlpha(other.layer == layerFilter and 1 or 0.5)
            end
            ns.Refresh()
        end)
        b:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(seg[2], 1, 1, 1)
            GameTooltip:AddLine(seg[3], 0.6, 0.66, 0.75, true)
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetAlpha(seg[1] == layerFilter and 1 or 0.5)
        segButtons[#segButtons + 1] = b
        x = x + b:GetWidth() + 4
    end

    local free = API.Button(bar, "Show free only", 24)
    free:SetWidth(120)
    free:SetPoint("LEFT", bar, "LEFT", x + 12, 0)
    free:SetAlpha(0.5)
    free:SetScript("OnClick", function()
        freeOnly = not freeOnly
        free:SetAlpha(freeOnly and 1 or 0.5)
        ns.Refresh()
    end)

    -- top row: keyboard on the left, mouse on its right ----------------
    local board = CreateFrame("Frame", nil, panel)
    board:SetPoint("TOPLEFT", 20, -96)
    LayoutBoard(board)

    local boardW, boardH = board:GetWidth(), board:GetHeight()

    local mouseCap = API.Text(panel, "tiny", "LEFT")
    mouseCap:SetText("MOUSE")
    mouseCap:SetTextColor(0.31, 0.34, 0.40)

    local mouse = CreateFrame("Frame", nil, panel)
    mouse:SetPoint("TOPLEFT", mouseCap, "BOTTOMLEFT", 0, -12)
    LayoutMouse(mouse)

    local topH = math.max(boardH, mouse:GetHeight() + 28)
    local SECTION_Y = 96 + topH + 36

    -- The window is only as wide as the wider of its two rows: the board
    -- plus the mouse up top, or the mapping section plus the legend below.
    -- A tenkeyless board makes for a narrower window than a full-size one.
    local SLOT_W, RESULT_W, SIDE_W = 360, 380, 320
    local MAPPING_W = SLOT_W + 30 + RESULT_W
    local PANEL_W = math.max(20 + boardW + 44 + mouse:GetWidth() + 20,
                             20 + MAPPING_W + 40 + SIDE_W + 20)
    ns.anchor:SetWidth(PANEL_W)

    -- centre the mouse in whatever room is left beside the board
    local slack = (PANEL_W - 40 - boardW - mouse:GetWidth())
    mouseCap:SetPoint("TOPLEFT", panel, "TOPLEFT",
        20 + boardW + math.max(44, math.floor(slack / 2)), -96)

    -- bottom left: the mapping section ---------------------------------
    local mapping = CreateFrame("Frame", nil, panel)
    mapping:SetPoint("TOPLEFT", 20, -SECTION_Y)
    mapping:SetSize(MAPPING_W, 10)

    local rh = API.Text(mapping, "tiny", "LEFT")
    rh:SetPoint("TOPLEFT")
    rh:SetText("SELECTED KEY")
    rh:SetTextColor(0.42, 0.46, 0.52)

    local big = MakeTile(mapping)
    big:SetSize(70, 46)
    big:SetPoint("TOPLEFT", rh, "BOTTOMLEFT", 0, -10)
    big:EnableMouse(false)
    big:Paint(0)
    big.label:SetText("")
    big.count:SetText("")

    panel.selKey = API.Text(big, "body")
    panel.selKey:SetPoint("CENTER")

    panel.selTitle = API.Text(mapping, "small", "LEFT")
    panel.selTitle:SetPoint("TOPLEFT", big, "TOPRIGHT", 12, -4)
    panel.selTitle:SetWidth(300)
    panel.selSub = API.Text(mapping, "tiny", "LEFT")
    panel.selSub:SetPoint("TOPLEFT", big, "TOPRIGHT", 12, -24)
    panel.selSub:SetWidth(300)
    panel.selSub:SetTextColor(0.42, 0.46, 0.52)

    local sh = API.Text(mapping, "tiny", "LEFT")
    sh:SetPoint("TOPLEFT", big, "BOTTOMLEFT", 0, -18)
    sh:SetText("BINDINGS ON THIS KEY")
    sh:SetTextColor(0.42, 0.46, 0.52)

    panel.slotHost = CreateFrame("Frame", nil, mapping)
    panel.slotHost:SetPoint("TOPLEFT", sh, "BOTTOMLEFT", 0, -10)
    panel.slotHost:SetWidth(SLOT_W)
    panel.slotHost:SetHeight(4 * 31)

    -- The search box and its results sit beside the slots rather than under
    -- them, so the mapping section stays one band across the bottom, and the
    -- box is right above the list it fills.
    local searchCap = API.Text(mapping, "tiny", "LEFT")
    searchCap:SetPoint("TOPLEFT", mapping, "TOPLEFT", SLOT_W + 30, 0)
    searchCap:SetText("SEARCH FOR ACTIONS")
    searchCap:SetTextColor(0.42, 0.46, 0.52)

    -- One button, not two: pressing it opens every heading and lights up,
    -- pressing it again shuts them. The light is worked out from the list
    -- itself on every refresh, so opening headings by hand keeps it honest.
    local expandAll = API.Button(mapping, "Expand all", 20)
    expandAll:SetWidth(84)
    -- Beside the caption of the list it acts on, with room to breathe, so it
    -- is nowhere near the search box or the filter below it.
    expandAll:SetPoint("LEFT", searchCap, "RIGHT", 20, 0)
    expandAll:SetAlpha(0.7)
    expandAll:SetScript("OnClick", function()
        if AllGroupsOpen() then
            wipe(browseOpen)
        else
            for _, group in ipairs(ns.CommandGroups()) do browseOpen[group.name] = true end
        end
        resultOffset = 0
        RefreshResults()
    end)
    expandAll:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(AllGroupsOpen() and "Collapse all" or "Expand all", 1, 1, 1)
        GameTooltip:AddLine(AllGroupsOpen()
            and "Shut every heading in the list below."
            or "Open every heading in the list below.", 0.6, 0.66, 0.75, true)
        GameTooltip:Show()
    end)
    expandAll:HookScript("OnLeave", function() GameTooltip:Hide() end)
    panel.expandAll = expandAll


    local hoverBind = API.Button(bar, "Bind on hover", 24)
    hoverBind:SetWidth(118)
    hoverBind:SetPoint("LEFT", free, "RIGHT", 8, 0)
    hoverBind:SetAlpha(0.5)
    hoverBind:SetScript("OnClick", function() ns.ToggleHoverBind() end)
    hoverBind:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Bind on hover", 1, 1, 1)
        GameTooltip:AddLine("Point at a button on one of Daylight UI's action bars and press the combo you want. It says what the key was doing before taking it. Escape to stop.", 0.6, 0.66, 0.75, true)
        GameTooltip:Show()
    end)
    hoverBind:HookScript("OnLeave", function() GameTooltip:Hide() end)
    panel.hoverBind = hoverBind

    -- the mode can be turned on from the slash command too, so it tells the
    -- button rather than the button owning the state
    function ns.SetHoverBindButton(on)
        if panel and panel.hoverBind then panel.hoverBind:SetAlpha(on and 1 or 0.5) end
    end

    local search = API.Input(mapping, {
        search = true,
        onChange = function(text)
            searchText = text or ""
            resultOffset = 0
            RefreshResults()
        end,
    })
    search:SetSize(RESULT_W - 128, 26)
    search:SetPoint("TOPLEFT", searchCap, "BOTTOMLEFT", 0, -8)
    panel.search = search

    -- One control for the list below: which actions it shows. There is no
    -- off state, because a list you have to summon is a list nobody finds.
    local filter = API.Button(mapping, FILTERS[1].label, 26)
    filter:SetWidth(120)
    filter:SetPoint("LEFT", search, "RIGHT", 8, 0)
    filter:SetScript("OnClick", function(self)
        filterIndex = (filterIndex % #FILTERS) + 1
        SetButtonLabel(self, FILTERS[filterIndex].label)
        self:SetAlpha(FilterKey() == "all" and 0.75 or 1)
        resultOffset = 0
        RefreshResults()
        if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
    end)
    filter:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(FILTERS[filterIndex].label, 1, 1, 1)
        GameTooltip:AddLine(FILTERS[filterIndex].tip, 0.6, 0.66, 0.75, true)
        GameTooltip:Show()
    end)
    filter:HookScript("OnLeave", function() GameTooltip:Hide() end)
    filter:SetAlpha(0.75)
    panel.filter = filter

    -- A control with three states has to say so without being hovered,
    -- or the two states nobody found may as well not exist.
    local filterHint = API.Text(mapping, "tiny")
    filterHint:SetPoint("TOP", filter, "BOTTOM", 0, -3)
    filterHint:SetText("Click to cycle")
    filterHint:SetTextColor(0.42, 0.46, 0.52)

    panel.resultsHead = API.Text(mapping, "tiny", "LEFT")
    panel.resultsHead:SetPoint("TOPLEFT", mapping, "TOPLEFT", SLOT_W + 30, -90)
    panel.resultsHead:SetText("MATCHING ACTIONS")
    panel.resultsHead:SetTextColor(0.42, 0.46, 0.52)
    panel.resultsHead:Hide()

    -- The window is a fixed height, so the list gets whatever room the band
    -- has and scrolls inside it rather than stretching the panel.
    local HEADER_H = 16 + 10 + 46 + 18 + 16 + 10
    local SIDE_H   = 356
    -- The actions list is the only one now, so it gets room to be read in
    -- rather than scrolled through eight lines at a time.
    local LIST_MIN = HEADER_H + 11 * ROW_H
    local band     = math.max(HEADER_H + #ns.Layers() * 31, SIDE_H, LIST_MIN)
    resultCount    = math.max(4, math.floor((band - HEADER_H) / ROW_H))

    panel.results = CreateFrame("Frame", nil, mapping)
    panel.results:SetPoint("TOPLEFT", panel.resultsHead, "BOTTOMLEFT", 0, -10)
    panel.results:SetWidth(RESULT_W)
    panel.results:SetHeight(resultCount * ROW_H)
    panel.results:Hide()
    panel.results:EnableMouseWheel(true)
    panel.results:SetScript("OnMouseWheel", function(_, delta)
        local overflow = math.max(0, resultTotal - resultCount)
        resultOffset = math.max(0, math.min(overflow, resultOffset - delta))
        RefreshResults()
    end)

    local sbar = CreateFrame("Frame", nil, panel.results)
    sbar:SetWidth(6)
    sbar:SetPoint("TOPRIGHT", panel.results, "TOPRIGHT", 0, -1)
    sbar:SetPoint("BOTTOMRIGHT", panel.results, "BOTTOMRIGHT", 0, 1)
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
    thumb:SetScript("OnEnter", function(self) self.tex:SetAlpha(1) end)
    thumb:SetScript("OnLeave", function(self) if not self.held then self.tex:SetAlpha(0.65) end end)
    thumb:SetScript("OnDragStart", function(self)
        self.held = true
        self.grabY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        self.grabOffset = resultOffset
    end)
    thumb:SetScript("OnDragStop", function(self)
        self.held = false
        self.tex:SetAlpha(0.65)
    end)
    thumb:SetScript("OnUpdate", function(self)
        if not self.held then return end
        local overflow = math.max(0, resultTotal - resultCount)
        local travel = sbar:GetHeight() - self:GetHeight()
        if overflow == 0 or travel <= 0 then return end
        local y = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        local moved = (self.grabY - y) / travel
        local want = math.floor(self.grabOffset + moved * overflow + 0.5)
        want = math.max(0, math.min(overflow, want))
        if want ~= resultOffset then
            resultOffset = want
            RefreshResults()
        end
    end)
    sbar.thumb = thumb
    panel.scrollbar = sbar

    -- bottom right: legend, counters, help ------------------------------
    local side = CreateFrame("Frame", nil, panel)
    side:SetPoint("TOPRIGHT", -20, -SECTION_Y)
    side:SetSize(SIDE_W, 10)

    local lh = API.Text(side, "tiny", "LEFT")
    lh:SetPoint("TOPLEFT")
    lh:SetText("LAYER DENSITY")
    lh:SetTextColor(0.42, 0.46, 0.52)

    local legendLabels = {
        [0] = "Unbound - free on every layer",
        [1] = "1 binding",
        [2] = "2 bindings",
        [3] = "3 bindings",
        [4] = "4+ bindings - key is crowded",
        [5] = "Not bindable - the game never sees it",
    }
    for i = 0, 5 do
        local sw = MakeTile(side)
        sw:SetSize(16, 16)
        sw:SetPoint("TOPLEFT", lh, "BOTTOMLEFT", 0, -10 - i * 24)
        if i == 5 then sw:PaintModifier() else sw:Paint(i) end
        sw.label:SetText("")
        sw:EnableMouse(false)

        local t = API.Text(side, "small", "LEFT")
        t:SetPoint("LEFT", sw, "RIGHT", 10, 0)
        t:SetText(legendLabels[i])
        t:SetTextColor(0.6, 0.64, 0.70)
    end

    -- Each counter explains itself on hover, because "free keys" is not
    -- self-evident: it counts mouse buttons and the nav cluster too.
    local function Stat(anchorX, anchorY, caption, tip)
        local hit = CreateFrame("Frame", nil, side)
        hit:SetPoint("TOPLEFT", lh, "BOTTOMLEFT", anchorX - 2, anchorY + 2)
        hit:SetSize(100, 44)
        hit:EnableMouse(true)

        local v = API.Text(side, "head", "LEFT")
        v:SetPoint("TOPLEFT", lh, "BOTTOMLEFT", anchorX, anchorY)
        local c = API.Text(side, "tiny", "LEFT")
        c:SetPoint("TOPLEFT", v, "BOTTOMLEFT", 0, -2)
        c:SetText(caption)
        c:SetTextColor(0.37, 0.41, 0.47)

        hit:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine(caption, 1, 1, 1)
            GameTooltip:AddLine(tip, 0.6, 0.66, 0.75, true)
            if self.listing then self.listing() end
            GameTooltip:Show()
        end)
        hit:SetScript("OnLeave", function() GameTooltip:Hide() end)

        v.hit = hit
        return v
    end
    -- The top row is about this keyboard: every key-and-modifier slot on it
    -- is either used or free, and the two always add up. The line below is
    -- about the game instead, which is why its numbers never match.
    panel.statBound = Stat(0, -170, "USED SLOTS",
        "Key-and-modifier slots filled on the board above. This and Free slots always add up to every slot this keyboard has.")

    panel.statSlots = Stat(110, -170, "FREE SLOTS",
        "Slots still empty: the free keys, plus the spare layers on keys already in use.")

    panel.statKeys = Stat(220, -170, "FREE KEYS",
        "Keys with nothing on any of their slots. Mouse buttons, the nav cluster and the arrows all count as keys.")

    panel.statActions = Stat(0, -226, "ACTIONS BOUND",
        "Something different: actions, not slots. How many of everything the game and your addons offer have at least one key. An action on two keys counts once, and a key off this board still counts, so this will not match Slots used.")
    panel.statActions:SetTextColor(unpack(TEXT[4]))
    panel.statActions.hit:SetSize(140, 44)

    panel.statDoubles = Stat(165, -226, "ON TWO KEYS",
        "Actions reachable from two different keys. Two is WoW's limit, so this is every action with more than one. Use the filter by the search box to list them.")
    panel.statDoubles:SetTextColor(unpack(TEXT[2]))
    panel.statDoubles.hit:SetSize(120, 44)

    -- the free-keys tooltip names them, so the number is never a mystery
    panel.statKeys.hit.listing = function()
        local list = ns.FreeKeyList()
        GameTooltip:AddLine(" ")
        if #list == 0 then
            GameTooltip:AddLine("Nothing is completely free.", 0.94, 0.54, 0.54)
            return
        end
        local line = {}
        for i, key in ipairs(list) do
            line[#line + 1] = ns.ShortKeyName(key)
            if #line == 4 or i == #list then
                GameTooltip:AddLine(table.concat(line, "   "), unpack(TEXT[0]))
                line = {}
            end
        end
    end

    local hint = API.Text(side, "tiny", "LEFT")
    hint:SetPoint("TOPLEFT", lh, "BOTTOMLEFT", 0, -280)
    hint:SetWidth(320)
    hint:SetText("Pick a key, then an action from the list. Or click an action on its own and press the combo you want. Bind on hover does it straight from the bars.")
    hint:SetTextColor(0.46, 0.50, 0.57)

    panel.combat = API.Text(side, "tiny", "LEFT")
    panel.combat:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -10)
    panel.combat:SetWidth(320)
    panel.combat:SetText("Bindings are locked in combat - the map stays readable.")
    panel.combat:SetTextColor(0.75, 0.54, 0.54)
    panel.combat:Hide()

    -- The panel is only as tall as the bottom band actually needs, and the
    -- band grows the moment search results appear rather than keeping room
    -- for them the rest of the time.
    ns.anchor:SetHeight(SECTION_Y + band + 74)

    -- footer ----------------------------------------------------------
    panel.discard = API.Button(panel, "Discard changes", 26)
    panel.discard:SetWidth(150)
    panel.discard:SetPoint("BOTTOMRIGHT", -180, 16)
    panel.discard:SetScript("OnClick", function()
        if not ns.IsDirty() then
            Say("Nothing to discard - no changes since you opened the map.")
            return
        end
        ns.Discard()
        Say("Changes discarded.")
        ns.Refresh()
    end)

    panel.save = API.Button(panel, "Save map", 26)
    panel.save:SetWidth(110)
    panel.save:SetPoint("BOTTOMRIGHT", -20, 16)
    panel.save:SetScript("OnClick", function()
        if not ns.IsDirty() then
            Say("Nothing to save - no changes since you opened the map.")
            return
        end
        local ok, why = ns.Save()
        Say(ok and "Bindings saved." or why)
        ns.Refresh()
    end)
    if API.MainButton then API.MainButton(panel.save, true) end

    -- Taking bindings out and putting them back. An addon cannot write a
    -- file, so both ends of that are a box of text.
    panel.export = API.Button(panel, "Export", 26)
    panel.export:SetWidth(92)
    panel.export:SetPoint("BOTTOMLEFT", 20, 16)
    panel.export:SetScript("OnClick", function() ns.ShowExport() end)
    panel.export:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Export bindings", 1, 1, 1)
        GameTooltip:AddLine("Copy every binding out as text you can keep in a file.",
            0.6, 0.66, 0.75, true)
        GameTooltip:Show()
    end)
    panel.export:SetScript("OnLeave", function() GameTooltip:Hide() end)

    panel.import = API.Button(panel, "Import", 26)
    panel.import:SetWidth(92)
    panel.import:SetPoint("BOTTOMLEFT", 118, 16)
    panel.import:SetScript("OnClick", function() ns.ShowImport() end)
    panel.import:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Import bindings", 1, 1, 1)
        GameTooltip:AddLine("Paste an export back in. Discard changes undoes it.",
            0.6, 0.66, 0.75, true)
        GameTooltip:Show()
    end)
    panel.import:SetScript("OnLeave", function() GameTooltip:Hide() end)

    panel.note = API.Text(panel, "tiny", "LEFT")
    panel.note:SetPoint("BOTTOMLEFT", 20, 50)
    panel.note:SetText("Saving to your "
        .. (ns.Get("scope") == "character" and "character" or "account") .. " bindings.")
    panel.note:SetTextColor(0.37, 0.41, 0.47)

    -- waiting for a key, having picked the action first ----------------
    local await = CreateFrame("Frame", nil, panel)
    await:SetSize(380, 112)
    await:SetPoint("CENTER", panel, "CENTER", 0, 0)
    await:SetFrameStrata("FULLSCREEN_DIALOG")
    await:EnableMouse(true)
    await:EnableKeyboard(false)
    await:EnableMouseWheel(true)
    API.Skin(await, { window = true })
    await:Hide()

    await.title = API.Text(await, "head", "LEFT")
    await.title:SetPoint("TOPLEFT", 16, -14)
    await.title:SetWidth(348)
    await.title:SetWordWrap(false)

    await.now = API.Text(await, "small", "LEFT")
    await.now:SetPoint("TOPLEFT", 16, -44)
    await.now:SetWidth(348)

    await.help = API.Text(await, "tiny", "LEFT")
    await.help:SetPoint("TOPLEFT", 16, -72)
    await.help:SetWidth(348)
    await.help:SetText("Press the combo you want. Delete clears it, Escape cancels.")
    await.help:SetTextColor(0.46, 0.50, 0.57)
    panel.await = await

    local AWAIT_IGNORED = {
        LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
        LALT = true, RALT = true, UNKNOWN = true,
    }

    local function TakeForAction(keyName)
        if not awaiting then return end
        if keyName == "ESCAPE" then StopAwaiting(); ns.Refresh(); return end
        if AWAIT_IGNORED[keyName] then return end

        local target = awaiting
        StopAwaiting()

        if keyName == "DELETE" then
            local a, b = ns.KeysForCommand(target.command)
            if a then ns.ClearBinding(a) end
            if b then ns.ClearBinding(b) end
            Say(target.name .. ": cleared.")
            ns.Refresh()
            return
        end

        local binding = ns.Compose(keyName, ns.CurrentLayer())
        local held = GetBindingAction(binding)
        if held ~= "" and held ~= target.command then
            Say(ns.PrettyBinding(binding) .. " was on " .. ns.CommandName(held) .. ".")
        end

        local ok, displaced = ns.AssignBinding(binding, target.command)
        if ok then
            Say(ns.PrettyBinding(binding) .. " -> " .. target.name)
        else
            Say(tostring(displaced))
        end
        ns.Refresh()
    end

    await:SetScript("OnKeyDown", function(_, keyName) TakeForAction(keyName) end)
    await:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" or button == "RightButton" then return end
        local n = button:match("^Button(%d+)$")
        if button == "MiddleButton" then n = 3 end
        if n and tonumber(n) > 2 then TakeForAction("BUTTON" .. n) end
    end)
    await:SetScript("OnMouseWheel", function(_, delta)
        TakeForAction(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
    end)

    -- key capture -----------------------------------------------------
    local capture = CreateFrame("Frame", nil, panel)
    capture:SetAllPoints()
    capture:SetFrameLevel(panel:GetFrameLevel() + 50)
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
        if keyName == "ESCAPE" then StopListening(); ns.Refresh(); return end
        if IGNORED[keyName] then return end

        local move = listening
        StopListening()

        local layer = ns.CurrentLayer()
        local allowed = false
        for _, l in ipairs(ns.Layers()) do if l == layer then allowed = true end end
        if not allowed then
            Say("That combo is on a layer the map is not showing. Turn on all eight layers in the options to use it.")
            ns.Refresh()
            return
        end

        if keyName == move.fromKey and layer == move.fromLayer then
            ns.Refresh()
            return
        end

        local ok, displaced = ns.Assign(keyName, layer, move.command)
        if not ok then
            Say(tostring(displaced))
            ns.Refresh()
            return
        end

        ns.Clear(move.fromKey, move.fromLayer)

        Say(ns.CommandName(move.command) .. ": " .. ns.Compose(move.fromKey, move.fromLayer)
            .. " -> " .. ns.Compose(keyName, layer))
        if displaced then Say("Took that key from " .. ns.CommandName(displaced) .. ".") end

        selected = keyName
        ns.Refresh()
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
    panel.capture = capture

    local watch = CreateFrame("Frame")
    watch:RegisterEvent("PLAYER_REGEN_DISABLED")
    watch:RegisterEvent("PLAYER_REGEN_ENABLED")
    watch:RegisterEvent("UPDATE_BINDINGS")
    watch:RegisterEvent("ADDON_LOADED")
    watch:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then StopListening() end
        ns.Refresh()
    end)


    -- Going into unlock mode means the player wants Daylight UI's grid and
    -- magnets back, so hand the frame over again.
    my.On("UnlockChanged", function(unlocked)
        if unlocked and my.SuspendMover then my.SuspendMover("panel", false) end
    end)

    panel:Hide()
end

----------------------------------------------------------------------
-- Show / hide
----------------------------------------------------------------------
function ns.ShowPanel()
    if not panel then Build() end
    ns.anchor:Show()
    panel:Show()
    ns.anchor:Raise()
    ns.Refresh()
end

function ns.HidePanel()
    if not panel then return end
    StopListening()
    StopAwaiting()
    armed = nil
    if ns.IsDirty() then
        local ok, why = ns.Save()
        if not ok then Say(why .. " Your changes are still pending.") end
    end
    panel:Hide()
    if ns.anchor then ns.anchor:Hide() end
end

function ns.TogglePanel()
    if panel and panel:IsShown() then ns.HidePanel() else ns.ShowPanel() end
end

local rebuildQueued = false

local function RebuildPanel()
    rebuildQueued = false
    if not panel then return end

    local wasShown = panel:IsShown()

    panel:Hide()
    if ns.anchor then ns.anchor:Hide() end

    -- the panel goes; the anchor and its mover stay
    panel:SetParent(nil)
    for _, t in ipairs(keyTiles or {}) do t:Hide(); t:SetParent(nil) end
    for _, t in ipairs(mouseBits or {}) do t:Hide(); t:SetParent(nil) end
    for _, r in ipairs(slotRows) do r:Hide(); r:SetParent(nil) end
    for _, r in ipairs(resultRows) do r:Hide(); r:SetParent(nil) end
    keyTiles, mouseBits, slotRows, resultRows = nil, nil, {}, {}
    selected, armed = nil, nil
    panel = nil

    if wasShown then ns.ShowPanel() end
end

my.On("SettingChanged", function(scope, path)
    if scope ~= ns.NAME or not panel then return end

    if path == "layout" or path == "size" or path == "mouseButtons" or path == "allLayers" then
        -- A slider fires on every step, so coalesce: rebuild once the
        -- player has stopped moving it rather than on each tick.
        if rebuildQueued then return end
        rebuildQueued = true
        C_Timer.After(0.2, RebuildPanel)

    elseif path == "scope" and panel.note then
        panel.note:SetText("Saving to your "
            .. (ns.Get("scope") == "character" and "character" or "account") .. " bindings.")
    end
end)
