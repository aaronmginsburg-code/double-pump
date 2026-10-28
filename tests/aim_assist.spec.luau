--!nocheck
local T = require("./runner/T")
local L = require("./runner/Loader")
L.reset()
local C = L.require(L.Shared.AimAssist.Config)
local P = L.require(L.Shared.AimAssist.Policy)
local Store = L.require(L.Shared.AimAssist.ProfileStore)
local Access = L.require(L.Server.Services.DeveloperAccess)
T.describe("Aim assist safety and response", function()
	T.it("validates all defaults without aliases", function()
		T.expect(C.validate(C.defaults())).toEqual(C.defaults())
	end)
	T.it("rejects NaN infinities malformed unknown or missing values", function()
		for _, bad in { 0 / 0, math.huge, -1, 0.81, ".4" } do
			local c = C.defaults()
			c.slowdownStrength = bad
			T.expect(C.validate(c)).toBe(nil)
		end
		local c = C.defaults()
		c.fake = true
		T.expect(C.validate(c)).toBe(nil)
		c = C.defaults()
		c.enabled = nil
		T.expect(C.validate(c)).toBe(nil)
	end)
	T.it("accepts range endpoints and rejects beyond every bound", function()
		for _, f in C.Fields do
			if f.min then
				for _, v in { f.min, f.max } do
					local c = C.defaults()
					c[f.key] = v
					T.expect(C.validate(c)).toBeTruthy()
				end
				for _, v in { f.min - 0.01, f.max + 0.01 } do
					local c = C.defaults()
					c[f.key] = v
					T.expect(C.validate(c)).toBe(nil)
				end
			end
		end
	end)
	T.it("master disable and keyboard produce exact identity", function()
		local c = C.defaults()
		local s, y, p = P.response(c, 0.5, 0, 0.016, "Keyboard", true, 1, 1)
		T.expect({ s, y, p }).toEqual({ 1, 0, 0 })
		c.enabled = false
		s, y, p = P.response(c, 0.5, 0, 0.016, "Touch", true, 1, 1)
		T.expect({ s, y, p }).toEqual({ 1, 0, 0 })
	end)
	T.it("slowdown eases toward configured floor and restores smoothly", function()
		local c = C.defaults()
		local s = P.response(c, 1, 0, 0.016, "Touch", true, 0, 0)
		T.expect(s).toBeLessThan(1)
		T.expect(s).toBeGreaterThan(0.6)
		for _ = 1, 100 do
			s = P.response(c, s, 0, 0.016, "Touch", true, 0, 0)
		end
		T.expect(s).toBeNear(0.6, 1e-6)
		local recovered = P.response(c, s, nil, 0.016, "Touch", true, 0, 0)
		T.expect(recovered).toBeGreaterThan(s)
		T.expect(recovered).toBeLessThan(1)
	end)
	T.it("slowdown never reaches zero or reverses manual control", function()
		local c = C.defaults()
		c.slowdownStrength = 0.8
		local s = 1
		for _ = 1, 100 do
			s = P.response(c, s, 0, 0.05, "Gamepad", true, 0, 0)
		end
		T.expect(s).toBeAtLeast(0.2)
	end)
	T.it("rotation requires current-frame aim input", function()
		local _, y, p = P.response(C.defaults(), 1, 0, 0.016, "Gamepad", false, 1, 1)
		T.expect({ y, p }).toEqual({ 0, 0 })
	end)
	T.it("independent toggles isolate slowdown and rotation", function()
		local c = C.defaults()
		c.rotationEnabled = false
		local s, y, p = P.response(c, 1, 0, 0.016, "Touch", true, 1, 1)
		T.expect(s).toBeLessThan(1)
		T.expect({ y, p }).toEqual({ 0, 0 })
		c.slowdownEnabled = false
		c.rotationEnabled = true
		s, y, p = P.response(c, 0.4, 0, 0.016, "Touch", true, 1, 1)
		T.expect(s).toBe(1)
		T.expect(y).toBeGreaterThan(0)
	end)
	T.it("rotation preserves sign and limits total angular velocity", function()
		local c = C.defaults()
		local _, y, p = P.response(c, 1, 0, 0.016, "Touch", true, -1, 1)
		T.expect(y).toBeLessThan(0)
		T.expect(p).toBeGreaterThan(0)
		T.expect(math.sqrt(y * y + p * p)).toBeAtMost(math.rad(35) * c.rotationStrength * 0.016 + 1e-9)
	end)
	T.it("zero tracking and stall clamping cannot snap", function()
		local c = C.defaults()
		c.trackingSpeed = 0
		local _, y, p = P.response(c, 1, 0, 1, "Touch", true, 3, 3)
		T.expect({ y, p }).toEqual({ 0, 0 })
		c.trackingSpeed = 30
		_, y, p = P.response(c, 1, 0, 1, "Touch", true, 3, 3)
		T.expect(math.sqrt(y * y + p * p)).toBeAtMost(math.rad(35) * c.rotationStrength * 0.05 + 1e-9)
	end)
	T.it("normalized radius remains consistent across phone and desktop", function()
		for _, size in { { 844, 390 }, { 1920, 1080 }, { 1024, 768 } } do
			local w, h = unpack(size)
			T.expect(P.inRadius(w / 2 + h * 0.1, h / 2, w, h, 0.12)).toBeTruthy()
			T.expect(P.inRadius(w / 2 + h * 0.13, h / 2, w, h, 0.12)).toBeFalsy()
		end
	end)
	T.it("target stability requires configured relative improvement", function()
		T.expect(P.choose({ { id = 1, score = 0.5 }, { id = 2, score = 0.45 } }, 1, 0.2).id).toBe(1)
		T.expect(P.choose({ { id = 1, score = 0.5 }, { id = 2, score = 0.35 } }, 1, 0.2).id).toBe(2)
		T.expect(P.choose({ { id = 2, score = 0.35 } }, 1, 0.2).id).toBe(2)
		T.expect(P.choose({}, 1, 0.2)).toBe(nil)
	end)
	T.it("context excludes self dead frozen teammates and cross-match targets", function()
		local a = { id = 1, alive = true, context = "Match", matchId = 7, team = "Red" }
		local b = { id = 2, alive = true, context = "Match", matchId = 7, team = "Blue" }
		T.expect(P.context(a, b)).toBeTruthy()
		for k, v in { id = 1, alive = false, frozen = true, team = "Red", matchId = 8, context = "Lobby" } do
			local x = table.clone(b)
			x[k] = v
			T.expect(P.context(a, x)).toBeFalsy()
		end
	end)
	T.it("lobby permits living nonlethal practice targets only", function()
		local a = { id = 1, alive = true, context = "Lobby" }
		T.expect(P.context(a, { id = 2, alive = true, context = "Lobby" })).toBeTruthy()
		T.expect(P.context(a, { id = 3, alive = true, dummy = true })).toBeTruthy()
		T.expect(P.context(a, { id = 2, alive = true, context = "Match" })).toBeFalsy()
	end)
	T.it("allowlist rejects ordinary synthetic and production identities", function()
		T.expect(Access.allowed(11808586604, 10772492892, 139437092998076)).toBeFalsy()
		for _, id in { 1, -1, 0, 11808586605 } do
			T.expect(Access.allowed(id, 10772492892, 139437092998076)).toBeFalsy()
		end
		T.expect(Access.allowed(11808586604, 10772275012, 82505574993280)).toBeFalsy()
		T.expect(Access.allowed(11808586604, 10772492892, 82505574993280)).toBeFalsy()
	end)
end)
T.describe("Developer tuning persistence", function()
	local function adapter()
		return {
			value = nil,
			GetAsync = function(self)
				return self.value
			end,
			UpdateAsync = function(self, _, fn)
				local result = fn(self.value)
				if result then
					self.value = result
				end
				return result
			end,
		}
	end
	T.it("explicit empty load then CAS save and rejoin load", function()
		local db = adapter()
		local s = Store.new(db)
		T.expect(s:load("slot").revision).toBe(0)
		local r = s:save("slot", 0, C.defaults())
		T.expect(r.revision).toBe(1)
		local later = Store.new(db):load("slot")
		T.expect(later.values).toEqual(C.defaults())
	end)
	T.it("stale save cannot overwrite another developer session", function()
		local db = adapter()
		local s = Store.new(db)
		s:save("slot", 0, C.defaults())
		local c = C.defaults()
		c.enabled = false
		local r = s:save("slot", 0, c)
		T.expect(r).toBe(nil)
		T.expect(db.value.values.enabled).toBeTruthy()
	end)
	T.it("invalid saved schema or range is never overwritten", function()
		for _, v in { { schema = 99, revision = 1, values = C.defaults() }, { schema = 1, revision = 1, values = {} } } do
			local db = adapter()
			db.value = v
			local s = Store.new(db)
			T.expect(s:load("slot")).toBe(nil)
			T.expect(s:save("slot", 0, C.defaults())).toBe(nil)
			T.expect(db.value).toEqual(v)
		end
	end)
	T.it("read and write failures retain current configuration", function()
		local db = {
			GetAsync = function()
				error("offline")
			end,
			UpdateAsync = function()
				error("offline")
			end,
		}
		local c = C.defaults()
		T.expect(Store.new(db):load("slot")).toBe(nil)
		T.expect(Store.new(db):save("slot", 0, c)).toBe(nil)
		T.expect(c).toEqual(C.defaults())
	end)
	T.it("UpdateAsync retry revalidates revision", function()
		local db = adapter()
		db.UpdateAsync = function(self, _, fn)
			fn(nil)
			self.value = { schema = 1, revision = 1, values = C.defaults() }
			return fn(self.value)
		end
		T.expect(Store.new(db):save("slot", 0, C.defaults())).toBe(nil)
	end)
end)
T.describe("Public static aiming initialization", function()
	T.it("starts without privileged transport or developer authorization", function()
		L.reset()
		local oldServices, oldInstance, oldTask = table.clone(L.services), L.Instance, L.task
		local camera = {}
		local connected, got = false, false
		local event = {
			Connect = function()
				connected = true
			end,
		}
		local request = {
			InvokeServer = function(_, action)
				T.expect(action).toBe("Get")
				got = true
				return { ok = true, authorized = true, state = { schema = 1, revision = 3, values = C.defaults() } }
			end,
		}
		local folder = {
			WaitForChild = function(_, name)
				return if name == "Request" then request else { OnClientEvent = event }
			end,
		}
		L.services.Players = { LocalPlayer = {} }
		L.services.CollectionService = {
			GetTagged = function()
				return {}
			end,
			GetInstanceAddedSignal = function()
				return event
			end,
			GetInstanceRemovedSignal = function()
				return event
			end,
		}
		L.services.GuiService = {}
		local focusCallbacks = {}
		L.services.UserInputService = {
			WindowFocusReleased = {
				Connect = function(_, fn)
					focusCallbacks.release = fn
				end,
			},
			WindowFocused = {
				Connect = function(_, fn)
					focusCallbacks.focus = fn
				end,
			},
		}
		local rs = L.game:GetService("ReplicatedStorage")
		L.services.ReplicatedStorage = {
			Shared = L.Shared,
			WaitForChild = function()
				return folder
			end,
		}
		L.game.GameId = 10772275012
		L.game.PlaceId = 82505574993280
		local aimNode = L.game:GetService("StarterPlayer").StarterPlayerScripts.Client.Controllers
		L.inject(aimNode.CameraController, camera)
		L.inject(aimNode.InputController, {})
		L.Instance = {
			new = function(class)
				if class == "BindableEvent" then
					return { Fire = function() end }
				end
				return { FilterDescendantsInstances = {} }
			end,
		}
		-- RaycastParams is not in the loader environment; supply through base globals.
		local prior = L.RaycastParams
		L.RaycastParams = {
			new = function()
				return {}
			end,
		}
		L.task = {
			spawn = function(fn)
				fn()
			end,
		}
		local ok, err = pcall(function()
			local a = L.require(aimNode.AimAssistController)
			a.start()
			T.expect(connected).toBeTruthy()
			T.expect(got).toBeFalsy()
			T.expect(a.authorized).toBeFalsy()
			T.expect(a.revision).toBe(0)
			T.expect(a.values.slowdownStrength).toBe(0.54)
			focusCallbacks.release()
			T.expect(a.focused).toBeFalsy()
			focusCallbacks.focus()
			T.expect(a.focused).toBeTruthy()
			T.expect(camera.aimAssist).toBeTruthy()
		end)
		L.RaycastParams = prior
		L.services = oldServices
		L.Instance = oldInstance
		L.task = oldTask
		L.game.GameId = nil
		L.game.PlaceId = nil
		L.reset()
		assert(ok, err)
	end)
end)
L.reset()
