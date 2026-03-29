local addonId = "ActionStrip"

Command.Event.Attach(Event.Addon.Load.End, function(_, id)
    if id ~= addonId then return end
    print("Hello World")
end, addonId .. "_Load")