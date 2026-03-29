local addonId = "ActionStrip"

Command.Event.Attach(Event.Addon.Load.End, function(_, id)
    if id ~= addonId then return end

    local context = UI.CreateContext(addonId .. "_Context")
    local frame = UI.CreateFrame("Frame", addonId .. "_Frame", context)
    frame:SetWidth(200)
    frame:SetHeight(40)
    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -220, -10)
    frame:SetBackgroundColor(0, 0, 0, 0.7)

    local label = UI.CreateFrame("Text", addonId .. "_Label", frame)
    label:SetText("ActionStrip")
    label:SetFontSize(12)
    label:SetPoint("CENTER", frame, "CENTER")

    print("ActionStrip loaded.")
end, addonId .. "_Load")