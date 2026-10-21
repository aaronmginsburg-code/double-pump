--!strict
-- Plays the shotgun's baked Blender animations (ShotgunAnimData) by sampling bone deltas.
-- One looping base clip (Idle) plus one action clip at a time, with short crossfades.
-- Animations are purely visual: gameplay timing lives in WeaponState, and callers can
-- stop/replace a clip at any moment (cancellation never touches cooldowns).

local AnimData = require(script.Parent.ShotgunAnimData)

local AnimPlayer = {}
AnimPlayer.__index = AnimPlayer

type Clip = {
	fps: number,
	duration: number,
	loop: boolean,
	events: { [string]: number },
	frames: { [string]: { CFrame } }, -- bone -> frame CFrames
}

type Playing = {
	clip: Clip,
	name: string,
	time: number,
	speed: number,
	weight: number,
	fadeIn: number,
	fadingOut: boolean,
	fadeOut: number,
	firedEvents: { [string]: boolean },
	onEvent: ((string) -> ())?,
	onEnd: (() -> ())?,
	hold: boolean, -- keep the last frame instead of fading out
}

export type AnimPlayer = typeof(setmetatable(
	{} :: {
		set: { [string]: Clip },
		base: Playing?,
		action: Playing?,
		previous: Playing?, -- fading-out action
		pose: { [string]: CFrame },
	},
	AnimPlayer
))

local clipCache: { [string]: { [string]: Clip } } = {}

local function buildClips(setName: string): { [string]: Clip }
	if clipCache[setName] then
		return clipCache[setName]
	end
	local raw = (AnimData :: any)[setName]
	local clips = {}
	for name, data in raw do
		local frames = {}
		for bone, list in data.tracks do
			local cframes = table.create(#list)
			for i, f in list do
				cframes[i] = CFrame.new(f[1], f[2], f[3], f[4], f[5], f[6], f[7])
			end
			frames[bone] = cframes
		end
		local short = name:gsub("^PumpShotgun_", "")
		clips[short] = {
			fps = data.fps,
			duration = data.duration,
			loop = data.loop,
			events = data.events,
			frames = frames,
		}
	end
	clipCache[setName] = clips
	return clips
end

-- setName: "FirstPerson" or "ThirdPerson"
function AnimPlayer.new(setName: string): AnimPlayer
	return setmetatable({
		set = buildClips(setName),
		base = nil,
		action = nil,
		previous = nil,
		pose = {},
	}, AnimPlayer)
end

function AnimPlayer.has(self: AnimPlayer, name: string): boolean
	return self.set[name] ~= nil
end

function AnimPlayer.duration(self: AnimPlayer, name: string): number
	local clip = self.set[name]
	return if clip then clip.duration else 0
end

function AnimPlayer.eventTime(self: AnimPlayer, name: string, event: string): number?
	local clip = self.set[name]
	return clip and clip.events[event]
end

local function sampleClip(clip: Clip, t: number, out: { [string]: CFrame })
	local position = t * clip.fps
	for bone, frames in clip.frames do
		local n = #frames
		local i = math.floor(position)
		local alpha = position - i
		if i >= n - 1 then
			out[bone] = frames[n]
		elseif i < 0 then
			out[bone] = frames[1]
		else
			out[bone] = frames[i + 1]:Lerp(frames[i + 2], alpha)
		end
	end
end

function AnimPlayer.playBase(self: AnimPlayer, name: string)
	local clip = self.set[name]
	if clip then
		self.base = {
			clip = clip,
			name = name,
			time = 0,
			speed = 1,
			weight = 1,
			fadeIn = 0,
			fadingOut = false,
			fadeOut = 0,
			firedEvents = {},
			hold = false,
		}
	end
end

export type PlayOptions = {
	speed: number?,
	fadeIn: number?,
	fadeOut: number?,
	startAt: number?, -- seconds into the clip
	hold: boolean?,
	onEvent: ((string) -> ())?,
	onEnd: (() -> ())?,
}

-- Starts an action clip, replacing (and fading out) any current one.
function AnimPlayer.play(self: AnimPlayer, name: string, options: PlayOptions?)
	local clip = self.set[name]
	if not clip then
		return
	end
	local o = (options or {}) :: PlayOptions
	local current = self.action
	if current then
		current.fadingOut = true
		current.fadeOut = math.max(o.fadeIn or 0.05, 0.001)
		self.previous = current
	end
	self.action = {
		clip = clip,
		name = name,
		time = o.startAt or 0,
		speed = o.speed or 1,
		weight = if (o.fadeIn or 0.05) <= 0 then 1 else 0,
		fadeIn = o.fadeIn or 0.05,
		fadingOut = false,
		fadeOut = o.fadeOut or 0.08,
		firedEvents = {},
		onEvent = o.onEvent,
		onEnd = o.onEnd,
		hold = o.hold == true,
	}
end

function AnimPlayer.current(self: AnimPlayer): string?
	return if self.action and not self.action.fadingOut then self.action.name else nil
end

function AnimPlayer.stop(self: AnimPlayer, fadeOut: number?)
	if self.action then
		self.action.fadingOut = true
		self.action.fadeOut = fadeOut or 0.08
	end
end

local function advance(p: Playing, dt: number)
	local before = p.time
	p.time += dt * p.speed
	if p.onEvent then
		for event, at in p.clip.events do
			if not p.firedEvents[event] and before <= at and p.time >= at then
				p.firedEvents[event] = true
				p.onEvent(event)
			end
		end
	end
	if p.clip.loop and p.time >= p.clip.duration then
		p.time %= p.clip.duration
		table.clear(p.firedEvents)
	end
end

-- Steps time and returns the blended pose (bone -> model-space delta).
function AnimPlayer.update(self: AnimPlayer, dt: number): { [string]: CFrame }
	local pose = self.pose
	table.clear(pose)
	if self.base then
		advance(self.base, dt)
		sampleClip(self.base.clip, self.base.time, pose)
	end

	local function blend(p: Playing)
		local layer = {}
		sampleClip(p.clip, math.min(p.time, p.clip.duration), layer)
		for bone, cf in layer do
			local under = pose[bone]
			pose[bone] = if under and p.weight < 1 then under:Lerp(cf, p.weight) else cf
		end
	end

	local prev = self.previous
	if prev then
		prev.weight -= dt / prev.fadeOut
		if prev.weight <= 0 then
			self.previous = nil
		else
			blend(prev)
		end
	end

	local action = self.action
	if action then
		advance(action, dt)
		if action.fadingOut then
			action.weight -= dt / action.fadeOut
		elseif action.weight < 1 then
			action.weight = math.min(1, action.weight + dt / math.max(action.fadeIn, 1e-3))
		end
		if not action.clip.loop and action.time >= action.clip.duration and not action.fadingOut then
			local onEnd = action.onEnd
			action.onEnd = nil
			if not action.hold then
				action.fadingOut = true
			end
			if onEnd then
				onEnd()
			end
		end
		if self.action == action then
			if action.weight <= 0 then
				self.action = nil
			else
				blend(action)
			end
		elseif self.action then
			-- onEnd started another clip; still show this one's last frame this step
			blend(action)
		end
	end
	return pose
end

return AnimPlayer
