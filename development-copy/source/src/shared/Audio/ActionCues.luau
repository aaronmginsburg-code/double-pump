--!strict
-- Audio decisions only; no changes to weapon eligibility, hits, damage or rewards.
local ActionCues = {}
local metal = { Metal = true, DiamondPlate = true, CorrodedMetal = true, Foil = true }
local soft = {
	Air = true,
	Water = true,
	Sand = true,
	Ground = true,
	Grass = true,
	LeafyGrass = true,
	Fabric = true,
	Snow = true,
	Mud = true,
}
function ActionCues.impactCue(material: string, character: boolean): string?
	if character or soft[material] then
		return nil
	end
	if metal[material] then
		return "ImpactMetal"
	end
	if material == "Wood" or material == "WoodPlanks" then
		return "ImpactWood"
	end
	return "ImpactHard"
end
function ActionCues.impacts(hits: { any }): { any }
	local result, seen = {}, {}
	for _, hit in hits do
		if not hit.instance or not hit.material then
			continue
		end
		local cue = ActionCues.impactCue(hit.material.Name, hit.isCharacter == true)
		if cue and not seen[cue] then
			seen[cue] = true
			table.insert(result, { cue = cue, position = hit.position })
			if #result == 2 then
				break
			end
		end
	end
	return result
end
function ActionCues.newClock(): any
	return { round = nil, phase = "", previous = math.huge, warned = false }
end
function ActionCues.clock(s: any, round: number, phase: string, left: number): string?
	if s.round ~= round then
		s.round, s.phase, s.previous, s.warned = round, "", math.huge, false
	end
	local previousPhase, previousTime = s.phase, s.previous
	s.phase, s.previous = phase, left
	if phase == "Overtime" and previousPhase ~= "Overtime" then
		return "Overtime"
	end
	if
		phase == "Active"
		and previousPhase == "Active"
		and not s.warned
		and previousTime > 30
		and left <= 30
		and left > 0
	then
		s.warned = true
		return "TimeWarning"
	end
	return nil
end
function ActionCues.skinChanged(previous: any, snapshot: any): (string?, boolean)
	local skin = typeof(snapshot) == "table" and typeof(snapshot.equipped) == "table" and snapshot.equipped.skin
	if typeof(skin) ~= "string" then
		return previous, false
	end
	return skin, typeof(previous) == "string" and previous ~= skin
end
-- One contextual bed; global arena state never replaces a lobby player's range bed.
function ActionCues.ambience(mode: string, participant: boolean, phase: string, arena: any): string?
	if mode == "Practice" then
		return "RangeAir"
	end
	if mode ~= "Match" or not participant then
		return nil
	end
	if phase ~= "Starting" and phase ~= "Active" and phase ~= "Overtime" and phase ~= "Results" then
		return nil
	end
	if arena == "AmbWarehouse" or arena == "AmbDustTown" or arena == "AmbRooftops" then
		return arena
	end
	return nil
end
return ActionCues
