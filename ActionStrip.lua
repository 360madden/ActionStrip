--[[
  ActionStrip — pixel telemetry bridge (v1)

  Screen region: anchored TOPRIGHT of UIParent, inset (-24, 24). Root frame holds
  name labels and a bar column. Eight horizontal rows are stacked downward; each
  row is BAR_W x ROW_H logical pixels (solid fill, opaque).

  Pixel reader: sample the vertical center of each row, left-to-right within the
  solid bar (avoid text to the left). Colors use additive-friendly channels:
    R = normalized metric in [0, 1]
    G = row index / 7  (row id: 0..1, helps verify which strip was read)
    B = 12/255  (protocol marker)

  Channel map (row index 0..7):
    0 = player HP (health / healthMax)
    1 = player primary resource (mana, energy, or charge % — first applicable)
    2 = player cast progress (1 - remaining/duration while casting, else 0)
    3 = player planar (planar / planarMax) or 0 if unavailable
    4 = target HP (0 if no target)
    5 = target primary resource %
    6 = target cast progress
    7 = target present (1 if valid target, else 0)

  Unit specifiers: "player", "player.target" (RIFT-style). Names are plain Text
  beside the strip; not encoded in pixel channels.
]]

local addonId = "ActionStrip"

local ROW_COUNT = 8
local ROW_H = 6
local BAR_W = 128
local LABEL_W = 200
local PROTO_B = 12 / 255

local playerSpec = "player"
local targetSpec = "player.target"

local function clamp01(x)
    if x == nil then return 0 end
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

local function fraction(n, d)
    if not n or not d or d <= 0 then return 0 end
    return clamp01(n / d)
end

--- Prefer mana, then energy, then charge for "primary" resource bar.
local function primaryResourceFraction(detail)
    if not detail then return 0 end
    local m = fraction(detail.mana, detail.manaMax)
    if detail.manaMax and detail.manaMax > 0 then return m end
    local e = fraction(detail.energy, detail.energyMax)
    if detail.energyMax and detail.energyMax > 0 then return e end
    local c = fraction(detail.charge, detail.chargeMax)
    if detail.chargeMax and detail.chargeMax > 0 then return c end
    return 0
end

local function planarFraction(detail)
    if not detail then return 0 end
    return fraction(detail.planar, detail.planarMax)
end

local function castProgress(castbar)
    if not castbar then return 0 end
    local d = castbar.duration
    local r = castbar.remaining
    if not d or d <= 0 then return 0 end
    if r == nil then r = 0 end
    if r < 0 then r = 0 end
    return clamp01(1 - (r / d))
end

local function targetIsValid(detail)
    if not detail then return false end
    if detail.healthMax and detail.healthMax > 0 then return true end
    if detail.name and detail.name ~= "" then return true end
    return false
end

local function encodeMetricRow(rowIndex, value)
    local r = clamp01(value)
    local g = (ROW_COUNT <= 1) and 0 or (rowIndex / (ROW_COUNT - 1))
    return r, g, PROTO_B
end

Command.Event.Attach(Event.Addon.Load.End, function(_, id)
    if id ~= addonId then return end

    local context = UI.CreateContext(addonId .. "_Context")
    local root = UI.CreateFrame("Frame", addonId .. "_Root", context)
    root:SetWidth(LABEL_W + BAR_W + 8)
    root:SetHeight(ROW_COUNT * ROW_H + 40)
    root:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -24, 24)
    root:SetBackgroundColor(0, 0, 0, 0.75)

    local title = UI.CreateFrame("Text", addonId .. "_Title", root)
    title:SetText("ActionStrip telemetry")
    title:SetFontSize(11)
    title:SetPoint("TOPLEFT", root, "TOPLEFT", 6, 4)

    local namePlayer = UI.CreateFrame("Text", addonId .. "_NamePlayer", root)
    namePlayer:SetFontSize(10)
    namePlayer:SetPoint("TOPLEFT", root, "TOPLEFT", 6, 22)
    namePlayer:SetWidth(LABEL_W)

    local nameTarget = UI.CreateFrame("Text", addonId .. "_NameTarget", root)
    nameTarget:SetFontSize(10)
    nameTarget:SetPoint("TOPLEFT", namePlayer, "BOTTOMLEFT", 0, 2)
    nameTarget:SetWidth(LABEL_W)

    local barColumn = UI.CreateFrame("Frame", addonId .. "_BarColumn", root)
    barColumn:SetWidth(BAR_W)
    barColumn:SetHeight(ROW_COUNT * ROW_H)
    barColumn:SetPoint("TOPRIGHT", root, "TOPRIGHT", -6, 38)

    local rows = {}
    for i = 0, ROW_COUNT - 1 do
        local row = UI.CreateFrame("Frame", addonId .. "_Row" .. i, barColumn)
        row:SetWidth(BAR_W)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", barColumn, "TOPLEFT", 0, i * ROW_H)
        row:SetBackgroundColor(0, 0, PROTO_B, 1)
        rows[i + 1] = row
    end

    local function refresh()
        local pd = Inspect.Unit.Detail(playerSpec)
        local td = Inspect.Unit.Detail(targetSpec)
        local pc = Inspect.Unit.Castbar(playerSpec)
        local tc = Inspect.Unit.Castbar(targetSpec)

        local hasT = targetIsValid(td)
        if not hasT then td = nil end

        namePlayer:SetText(pd and pd.name and ("P: " .. pd.name) or "P: —")
        nameTarget:SetText(hasT and td and td.name and ("T: " .. td.name) or "T: —")

        local v = {}
        v[1] = fraction(pd and pd.health, pd and pd.healthMax)
        v[2] = primaryResourceFraction(pd)
        v[3] = castProgress(pc)
        v[4] = planarFraction(pd)
        v[5] = hasT and fraction(td.health, td.healthMax) or 0
        v[6] = hasT and primaryResourceFraction(td) or 0
        v[7] = hasT and castProgress(tc) or 0
        v[8] = hasT and 1 or 0

        for i = 1, ROW_COUNT do
            local r, g, b = encodeMetricRow(i - 1, v[i])
            rows[i]:SetBackgroundColor(r, g, b, 1)
        end
    end

    Command.Event.Attach(Event.System.Update.Begin, function()
        refresh()
    end, addonId .. "_Tick")

    print("ActionStrip telemetry loaded. Pixel bridge: " .. BAR_W .. "x" .. (ROW_COUNT * ROW_H) .. " TOPRIGHT inset (24,24).")
end, addonId .. "_Load")
