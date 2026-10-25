--!strict
-- Presentation-only distance cadence. Never writes movement or combat state.
local MovementCues = {}
MovementCues.Stride = 4
MovementCues.MinimumInterval = 0.16

export type State = {
	travel: number,
	elapsed: number,
	air: number,
	downward: number,
	grounded: boolean?,
	established: boolean,
}

function MovementCues.new(): State
	return { travel = 0, elapsed = 0, air = 0, downward = 0, grounded = nil, established = false }
end

function MovementCues.surface(material: string): string?
	if material == "Air" or material == "Water" then
		return nil
	elseif material == "Metal" or material == "DiamondPlate" or material == "CorrodedMetal" then
		return "StepMetal"
	elseif material == "Sand" or material == "Ground" then
		return "StepSand"
	elseif material == "Wood" or material == "WoodPlanks" then
		return "StepWood"
	end
	return "StepConcrete"
end

function MovementCues.advance(
	s: State,
	dt: number,
	distance: number,
	grounded: boolean,
	speed: number,
	vertical: number,
	enabled: boolean
): string?
	if not enabled or dt <= 0 or dt > 0.25 or distance > 12 then
		s.travel, s.elapsed, s.air, s.downward, s.grounded = 0, 0, 0, 0, nil
		s.established = false
		return nil
	end
	s.elapsed += dt
	if not grounded then
		s.air += dt
		s.downward = math.min(s.downward, vertical)
		s.travel = 0
		s.grounded = false
		return nil
	end
	local landed = s.established and s.grounded == false and s.air >= 0.08 and s.downward <= -5
	s.grounded, s.air, s.downward = true, 0, 0
	s.established = true
	if landed then
		s.travel, s.elapsed = 0, 0
		return "Landing"
	end
	if speed < 1.5 or distance > math.max(2, speed * dt * 3) then
		s.travel = 0
		return nil
	end
	s.travel += distance
	if s.travel >= MovementCues.Stride and s.elapsed >= MovementCues.MinimumInterval then
		-- At most one event per sample; a stall cannot produce a catch-up burst.
		s.travel %= MovementCues.Stride
		s.elapsed = 0
		return "Step"
	end
	return nil
end

return MovementCues
