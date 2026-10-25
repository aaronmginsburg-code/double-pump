--!strict
-- Canonical independent preferences; accept coupled legacy saves.
local Preferences = {}
function Preferences.side(value: any, fallback: string): string
	if value == "left" or value == "Left-Handed" then
		return "left"
	end
	if value == "right" or value == "Right-Handed" then
		return "right"
	end
	return fallback
end
function Preferences.normalize(raw: any): { controlLayout: string, weaponHand: string }
	local saved = if typeof(raw) == "table" then raw else {}
	local layout = Preferences.side(saved.controlLayout, "right")
	return { controlLayout = layout, weaponHand = Preferences.side(saved.weaponHand, layout) }
end
return Preferences
