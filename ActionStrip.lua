local addonId = "ActionStrip"

local function Init(h, id)
    if id ~= addonId then return end
    print("Hello World")
end

table.insert(Event.Addon.Load.End, { Init, addonId, "Init" })