--!strict
-- Reflect a local presentation transform: S*R*S stays a proper rotation.
-- Used only by the local viewmodel, never by shot origins or third-person rigs.
local Presentation = {}
function Presentation.reflect(cf: CFrame): CFrame
	local x, y, z, a, b, c, d, e, f, g, h, i = cf:GetComponents()
	return CFrame.new(-x, y, z, a, -b, -c, -d, e, f, -g, h, i)
end
return Presentation
