--!nocheck
-- (v35) How a bot moves: like a person at a keyboard, a phone or a gamepad - never on rails.
--  * A virtual camera and keys. Keyboard players hold W and A / D and drag the camera round now and then, so their
--    routes are short straight runs at 45-degree steps that bend towards the goal; thumbsticks steer smoothly with a
--    wobble (and a thumb that doesn't always push the stick all the way); shift-lock players face wherever the camera
--    looks and whip round in an instant. Humanoid:Move() gets that direction, so the body turns, speeds up and stops
--    exactly like a player's character, at the walk speed the bot's stats give it (ctx.setMovement, same formula).
--  * Routes: PathfindingService on the island (round fences, through gates), the planet's decor steered round on the
--    planets (Nav). Stuck: jump; still stuck: a step aside and a new route.
--  * Habits: bunny-hopping, a late stop and a small correction, looking back at whoever chases it, tapping A / D to turn
--    on the spot (a player without shift lock can't turn without moving).
--  * A bad connection now and then: the body freezes mid-stride - the animation keeps playing, as a laggy player's does
--    on everyone else's screen - and then snaps to where it got to.
--  * The jetpack the way a player flies it: in the air, "holding jump" thrusts at the pack's speed until its charge runs
--    out (Config.Jetpacks: FlightTime, Recharge, Thrust); the flames show for everyone (PFEJetting).
--  * Riding: held on a moving point (a meteor's top in the Meteor Run).
local Motor = {}
Motor.__index = Motor
local rng = Random.new()
local TAU = math.pi * 2

local function wrap(a) return (a + math.pi) % TAU - math.pi end
local function yawOf(v) return math.atan2(-v.X, -v.Z) end
local function dirOf(yaw) return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw)) end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
Motor.YawOf, Motor.DirOf, Motor.Wrap = yawOf, dirOf, wrap

-- lag spikes by connection: {seconds between, how long}
local PING = {
	Good = {Every = {150, 420}, Long = {0.12, 0.35}, Stutter = 0},
	Average = {Every = {40, 130}, Long = {0.2, 0.75}, Stutter = 0.02},
	Bad = {Every = {9, 35}, Long = {0.3, 1.5}, Stutter = 0.08},
}

function Motor.new(bot, env)
	local p = bot.Persona
	local ping = PING[p.Ping] or PING.Good
	local self = setmetatable({
		Bot = bot, Env = env, Persona = p,
		CamYaw = rng:NextNumber(-math.pi, math.pi), Dragging = false, DragSpeed = 3,
		DragStart = math.rad(rng:NextNumber(22, 55)), DragStop = math.rad(rng:NextNumber(4, 14)),
		Key = 0, KeyUntil = 0, WobbleT = rng:NextNumber(0, 1000),
		Goal = nil, ShiftLock = false, LookAt = nil, LookYaw = nil, Spin = nil, Pulse = nil,
		Jet = {Charge = 10, Locked = false, Want = 0, Air = 0, On = false},
		Ping = ping, LagNext = os.clock() + rng:NextNumber(ping.Every[1], ping.Every[2]), LagUntil = nil,
		StuckAt = os.clock(), StuckPos = nil, StuckCount = 0, Detour = nil, NextJumpCheck = 0,
		Paused = false, Ride = nil,
	}, Motor)
	return self
end

-- ---------------------------------------------------------------- goals
-- target: a Vector3 or a function returning one (a moving target). opts: Near, Timeout, Jet (jetpack hops on long
-- runs), Path (false: straight there), Evade (zig-zag, looking back at opts.Threat), Look (keep the camera on a point)
function Motor:GoTo(target, opts)
	opts = opts or {}
	if self.Goal and not self.Goal.Done then self.Goal.Done = true; self.Goal.Result = "Replaced" end
	local goal = {Target = target, Opts = opts, Near = opts.Near or 3.5, Started = os.clock(), Done = false, Result = nil,
		Path = nil, Index = 2, PathFor = nil, PathAt = 0, Planning = false, Side = 0, StopAt = nil, Timeout = opts.Timeout or 30}
	self.Goal = goal
	self.StuckAt, self.StuckPos, self.StuckCount = os.clock(), nil, 0
	return goal
end
function Motor:Cancel(goal)
	goal = goal or self.Goal
	if goal and not goal.Done then goal.Done = true; goal.Result = goal.Result or "Cancelled" end
	if self.Goal == goal then self.Goal = nil end
end
function Motor:Stop()
	self:Cancel(self.Goal)
	self.Pulse = nil
end
local function targetOf(goal)
	local t = goal.Target
	if type(t) == "function" then
		local ok, v = pcall(t)
		if ok and typeof(v) == "Vector3" then return v end
		return nil
	end
	return t
end

-- a short tap of the keys towards `yaw` (turning on the spot without shift lock)
function Motor:Tap(yaw, seconds)
	self.Pulse = {Yaw = yaw, Until = os.clock() + (seconds or 0.08)}
end
-- shift lock: a full spin of the camera (people do it for fun)
function Motor:DoSpin(turns, seconds)
	self.Spin = {From = self.CamYaw, Turns = turns or 1, Started = os.clock(), Seconds = seconds or 0.8}
end
function Motor:SetShiftLock(on)
	if self.ShiftLock == on then return end
	self.ShiftLock = on
	local h = self.Bot.Humanoid
	if h then pcall(function() h.AutoRotate = not on end) end
end
function Motor:JetFor(seconds) self.Jet.Want = os.clock() + seconds end
function Motor:JetOff() self.Jet.Want = 0 end

-- ---------------------------------------------------------------- the jetpack
function Motor:Pack()
	local Config = self.Env.Config
	return Config.Jetpacks[self.Bot.P and self.Bot.P.Data.JetpackLevel or 1] or Config.Jetpacks[1]
end
function Motor:SetJetting(on, root, thrust, dt)
	local model = self.Bot.Model
	local jet = self.Jet
	if on then
		local lv = jet.Constraint
		if not lv or lv.Parent ~= root then
			if lv then lv:Destroy() end
			local attachment = root:FindFirstChild("BotJetAttachment") or Instance.new("Attachment")
			attachment.Name = "BotJetAttachment"; attachment.Parent = root
			lv = Instance.new("LinearVelocity")
			lv.Name = "BotJet"
			lv.Attachment0 = attachment
			lv.RelativeTo = Enum.ActuatorRelativeTo.World
			lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
			lv.LineDirection = Vector3.new(0, 1, 0)
			lv.Parent = root
			jet.Constraint = lv
		end
		local mass = 10
		pcall(function() mass = root.AssemblyMass end)
		lv.MaxForce = mass * workspace.Gravity * 2.4
		-- towards the pack's climb speed, as the player's client does
		local v = root.AssemblyLinearVelocity.Y
		lv.LineVelocity = v + (thrust - v) * math.min(1, dt * 7)
		lv.Enabled = true
	elseif jet.Constraint then
		jet.Constraint.Enabled = false
	end
	if jet.On ~= on then
		jet.On = on
		if model and model.Parent then model:SetAttribute("PFEJetting", on) end
	end
end

-- ---------------------------------------------------------------- lag
function Motor:Freeze(seconds)
	local root = self.Bot.Model and self.Bot.Model:FindFirstChild("HumanoidRootPart")
	if not root or root.Anchored or self.LagUntil then return end
	self.LagFrom = root.CFrame
	self.LagVel = flat(root.AssemblyLinearVelocity)
	self.LagSeconds = seconds
	self.LagUntil = os.clock() + seconds
	root.Anchored = true
	if self.Bot.Animate then self.Bot.Animate.Frozen = true end
end
function Motor:Thaw()
	local bot = self.Bot
	local root = bot.Model and bot.Model:FindFirstChild("HumanoidRootPart")
	self.LagUntil = nil
	if bot.Animate then bot.Animate.Frozen = false end
	if not root then return end
	-- where it would have got to: on along the way it was running, if the way is clear and there is ground
	local from = self.LagFrom or root.CFrame
	local travel = self.LagVel * (self.LagSeconds or 0)
	if travel.Magnitude > 34 then travel = travel.Unit * 34 end
	local goal = self.Goal and not self.Goal.Done and targetOf(self.Goal)
	if goal and travel.Magnitude > 0.1 then
		local left = flat(goal - from.Position).Magnitude
		if travel.Magnitude > left then travel = travel.Unit * left end
	end
	local landed = from
	if travel.Magnitude > 0.5 then
		local Nav = self.Env.Nav
		local ignore = {bot.Model}
		local ahead = from.Position + travel
		local below = Nav.Ground(from.Position, 14, ignore)
		local ground = Nav.Ground(ahead, 14, ignore)
		local planet = bot.P and bot.P.Planet
		local inTree = planet and planet ~= "Base" and Nav.Inside(planet, ahead, 1.6)
		if ground and not inTree and Nav.Clear(from.Position, ahead, ignore) then
			-- the same height over the ground it lands on
			local hip = below and (from.Position.Y - below.Position.Y) or 3
			landed = CFrame.new(Vector3.new(ahead.X, ground.Position.Y + math.clamp(hip, 2, 6), ahead.Z)) * from.Rotation
		end
	end
	root.CFrame = landed
	root.Anchored = false
	pcall(function() root.AssemblyLinearVelocity = self.LagVel end)
	pcall(function() root:SetNetworkOwner(nil) end)
end

-- ---------------------------------------------------------------- the human at the controls
function Motor:Input(dt, want, near)
	local p = self.Persona
	local now = os.clock()
	-- the camera
	if self.Spin then
		local s = self.Spin
		local t = math.clamp((now - s.Started) / s.Seconds, 0, 1)
		self.CamYaw = wrap(s.From + TAU * s.Turns * t)
		if t >= 1 then self.Spin = nil end
	elseif self.ShiftLock then
		local lookYaw = self.LookYaw or want or self.CamYaw
		local err = wrap(lookYaw - self.CamYaw)
		if math.abs(err) > math.rad(80) and rng:NextNumber() < dt * 7 then
			self.CamYaw = lookYaw                                  -- a flick of the mouse
		else
			local speed = 6 + 9 * p.Skill
			self.CamYaw = wrap(self.CamYaw + math.clamp(err, -speed * dt, speed * dt))
		end
	elseif p.Input == "Keyboard" and want then
		local err = wrap(want - self.CamYaw)
		local start = near and math.rad(10) or self.DragStart
		if not self.Dragging and math.abs(err) > start then
			self.Dragging = true
			self.DragSpeed = rng:NextNumber(2.2, 5.5) * (0.7 + p.Skill * 0.6)
		end
		if self.Dragging then
			local step = self.DragSpeed * dt
			self.CamYaw = wrap(self.CamYaw + math.clamp(err, -step, step))
			if math.abs(err) < self.DragStop then
				self.Dragging = false
				self.DragStart = math.rad(rng:NextNumber(22, 55)); self.DragStop = math.rad(rng:NextNumber(4, 14))
			end
		end
	end
	if not want then return Vector3.zero end
	if p.Input == "Keyboard" or self.ShiftLock then
		if near then return dirOf(want) end   -- the last few studs: little taps straight at it
		-- the key combo nearest to where it wants to go (eight directions off the camera), held a moment
		local rel = wrap(want - self.CamYaw)
		local best = math.floor(rel / (math.pi / 4) + 0.5) * (math.pi / 4)
		if now >= self.KeyUntil or math.abs(wrap(best - self.Key)) >= math.rad(90) then
			if math.abs(wrap(best - self.Key)) > 0.01 then
				self.Key = best
				self.KeyUntil = now + rng:NextNumber(0.1, 0.32)
			end
		end
		return dirOf(self.CamYaw + self.Key)
	end
	-- a thumbstick (or a gamepad stick): any angle, a little wobble, not always pushed all the way
	self.WobbleT += dt
	local wobble = math.noise(self.WobbleT * 0.6, (self.Bot.Id or 1) * 0.37) * math.rad(p.Input == "Touch" and 16 or 8)
	local push = p.Input == "Touch" and math.clamp(p.Analog + math.noise(self.WobbleT * 0.3, 7.7) * 0.12, 0.55, 1) or 1
	return dirOf(want + wobble) * push
end

-- ---------------------------------------------------------------- every frame
function Motor:Step(dt)
	local bot = self.Bot
	local model, humanoid = bot.Model, bot.Humanoid
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if not root or not model.Parent or not humanoid or humanoid.Health <= 0 or bot.Dead then
		if self.Jet.On and root then self:SetJetting(false, root, 0, dt) end
		return
	end
	local now = os.clock()
	local Config = self.Env.Config
	local planet = bot.P and bot.P.Planet or "Base"
	-- a lag spike runs its course
	if self.LagUntil then
		if now >= self.LagUntil then self:Thaw() else return end
	end
	-- the jetpack charge and thrust
	local pack = self:Pack()
	local jet = self.Jet
	local airborne = humanoid.FloorMaterial == Enum.Material.Air
	jet.Air = airborne and jet.Air + dt or 0
	local thrusting = now < jet.Want and airborne and jet.Air > 0.2 and not jet.Locked and jet.Charge > 0
		and not root.Anchored and not humanoid.PlatformStand and not self.Ride
	if thrusting then
		jet.Charge = math.max(0, jet.Charge - dt)
		if jet.Charge <= 0 then jet.Locked = true end
	else
		local refill = pack.FlightTime / pack.Recharge * ((bot.P and bot.P.Minigame) and 3 or 1)
		jet.Charge = math.min(pack.FlightTime, jet.Charge + dt * refill)
		if jet.Locked and jet.Charge >= pack.FlightTime then jet.Locked = false end
	end
	self:SetJetting(thrusting, root, pack.Thrust, dt)
	-- riding something that moves
	if self.Ride then
		local ok, pos, vel = pcall(self.Ride)
		if ok and typeof(pos) == "Vector3" then
			local lv = self.RideConstraint
			if not lv or lv.Parent ~= root then
				local attachment = root:FindFirstChild("BotJetAttachment") or Instance.new("Attachment")
				attachment.Name = "BotJetAttachment"; attachment.Parent = root
				lv = Instance.new("LinearVelocity")
				lv.Name = "BotRide"; lv.Attachment0 = attachment; lv.RelativeTo = Enum.ActuatorRelativeTo.World
				lv.MaxForce = 1e6; lv.Parent = root
				self.RideConstraint = lv
			end
			lv.VectorVelocity = (vel or Vector3.zero) + (pos - root.Position) * 6
			humanoid:Move(Vector3.zero, false)
			return
		end
		self:StopRide()
	end
	if self.Paused or root.Anchored or humanoid.PlatformStand or humanoid.Sit then
		humanoid:Move(Vector3.zero, false)
		-- (v36) a goal still runs out while the body can't move (it waited forever before: the bot froze for good)
		local g = self.Goal
		if g and not g.Done and now - g.Started > g.Timeout then g.Done, g.Result = true, "Timeout" end
		return
	end
	local here = root.Position
	-- where it wants to go this frame
	local want, near, dist = nil, false, 0
	local goal = self.Goal
	if goal and not goal.Done then
		local target = targetOf(goal)
		if not target then
			goal.Done, goal.Result = true, "Lost"
		elseif now - goal.Started > goal.Timeout then
			goal.Done, goal.Result = true, "Timeout"
		else
			dist = flat(target - here).Magnitude
			if dist <= goal.Near and math.abs(target.Y - here.Y) < 14 then
				-- arrived: a person lets go of the keys a moment late
				goal.StopAt = goal.StopAt or (now + (goal.Opts.Exact and 0 or rng:NextNumber(0, 0.16) * (1.3 - self.Persona.Skill)))
				if now >= goal.StopAt then goal.Done, goal.Result = true, "Reached" end
			elseif goal.StopAt and dist > goal.Near * 2.5 then
				goal.StopAt = nil      -- overshot: back it goes
			end
			if not goal.Done then
				local aim = target
				-- the island: a proper route
				if planet == "Base" and goal.Opts.Path ~= false and dist > 14 then
					local moved = goal.PathFor and flat(goal.PathFor - target).Magnitude or math.huge
					if not goal.Planning and (goal.Path == nil or (moved > 10 and now - goal.PathAt > 1.2)) then
						goal.Planning = true
						local from = here
						task.spawn(function()
							local path = self.Env.Nav.IslandPath(from, target)
							goal.Planning = false
							if goal.Done then return end
							goal.PathAt, goal.PathFor = os.clock(), target
							goal.Path = path or false
							goal.Index, goal.Aim, goal.SightAt = 2, nil, 0
						end)
					end
					local path = goal.Path
					if path then
						-- the waypoints it has passed
						while goal.Index <= #path do
							local wp = path[goal.Index]
							local d = flat(wp.Position - here).Magnitude
							local nextWp = path[goal.Index + 1]
							if d < 3.5 or (nextWp and d < 5 and flat(nextWp.Position - here).Magnitude < flat(nextWp.Position - wp.Position).Magnitude) then
								if wp.Jump then humanoid.Jump = true end
								goal.Index += 1
							else
								break
							end
						end
						-- a person heads for the furthest point of the route they can see, cutting the corners (checked 5x a second)
						if now >= (goal.SightAt or 0) then
							goal.SightAt = now + 0.2
							local best = goal.Index
							local ignore = {model}
							for j = goal.Index + 1, math.min(#path, goal.Index + 6) do
								local wp = path[j]
								if wp.Jump or path[j - 1].Jump or flat(wp.Position - here).Magnitude > 32 then break end
								if self.Env.Nav.Clear(here, wp.Position + Vector3.new(0, 2.6, 0), ignore) then best = j else break end
							end
							goal.Aim = best
						end
						local aimIndex = math.max(goal.Aim or goal.Index, goal.Index)
						local wp = path[aimIndex]
						if wp then
							aim = wp.Position
							if aimIndex > goal.Index and flat(wp.Position - here).Magnitude < 3.5 then goal.Index = aimIndex + 1 end
							local jumpWp = path[goal.Index]
							if jumpWp and jumpWp.Jump and flat(jumpWp.Position - here).Magnitude < 5 then humanoid.Jump = true end
						end
					end
				end
				local to = flat(aim - here)
				if to.Magnitude > 0.05 then
					local d = to.Unit
					-- zig-zag away from whoever chases
					if goal.Opts.Evade then
						local t = now * (1.6 + self.Persona.Skill)
						d = (d + Vector3.new(-d.Z, 0, d.X) * math.sin(t + (bot.Id or 0)) * 0.55).Unit
					end
					-- step out of a stuck spot
					if self.Detour and now < self.Detour.Until then d = (d * 0.3 + self.Detour.Dir).Unit end
					-- planets: round the trees and rocks everyone else walks into
					if planet ~= "Base" and Config.Planets[planet] then
						local steered, side = self.Env.Nav.Steer(planet, here, d, math.clamp(dist, 4, 11), goal.Side, 1.9)
						d, goal.Side = steered, side
					end
					want = yawOf(d)
					near = dist < 6 and (goal.Path == nil or goal.Path == false or goal.Index > #goal.Path)
				end
				-- a jetpack hop on a long way, like players do
				if goal.Opts.Jet and dist > 70 and not airborne and jet.Charge >= pack.FlightTime * 0.9 and rng:NextNumber() < dt * 0.35 then
					humanoid.Jump = true
					self:JetFor(rng:NextNumber(0.8, math.min(pack.FlightTime * 0.6, 3.2)))
				end
			end
		end
	end
	-- the camera follows a point (a target it chases, someone behind it)
	if self.LookAt then
		local ok, point = pcall(self.LookAt)
		if ok and typeof(point) == "Vector3" and flat(point - here).Magnitude > 1 then self.LookYaw = yawOf(flat(point - here)) else self.LookYaw = nil end
	else
		self.LookYaw = nil
	end
	local move
	if self.Pulse and now < self.Pulse.Until then
		move = dirOf(self.Pulse.Yaw)
	else
		self.Pulse = nil
		move = self:Input(dt, want, near)
	end
	humanoid:Move(move, false)
	-- shift lock: the body faces the camera
	if self.ShiftLock then
		root.CFrame = CFrame.new(here) * CFrame.Angles(0, self.CamYaw, 0)
	elseif self.Spin == nil and humanoid.AutoRotate == false then
		humanoid.AutoRotate = true
	end
	local moving = move.Magnitude > 0.1
	-- jumping for the fun of it (some people never stop)
	if moving and not airborne then
		local rate = self.Persona.Jumpiness * (dist > 25 and 1 or 0.3)
		if rng:NextNumber() < rate * dt then humanoid.Jump = true end
	end
	-- stuck against something: jump; still stuck: a step aside and a new route
	if moving then
		if not self.StuckPos then self.StuckPos, self.StuckAt = here, now end
		if now - self.StuckAt > 0.7 then
			if flat(here - self.StuckPos).Magnitude < 1.2 then
				self.StuckCount += 1
				humanoid.Jump = true
				if self.StuckCount >= 3 then
					local side = rng:NextNumber() < 0.5 and -1 or 1
					local base = dirOf(want or self.CamYaw)
					self.Detour = {Dir = Vector3.new(-base.Z * side, 0, base.X * side), Until = now + rng:NextNumber(0.5, 1.1)}
					if goal and not goal.Done then goal.Path = nil end
				end
				if self.StuckCount >= 12 and goal and not goal.Done then goal.Done, goal.Result = true, "Stuck" end
			else
				self.StuckCount = 0
			end
			self.StuckPos, self.StuckAt = here, now
		end
		-- a lag spike (only while running about: that's when people notice them)
		if now >= self.LagNext and not airborne and not jet.On then
			local ping = self.Ping
			self.LagNext = now + rng:NextNumber(ping.Every[1], ping.Every[2])
			if self.Env.Watched == nil or self.Env.Watched(bot) then self:Freeze(rng:NextNumber(ping.Long[1], ping.Long[2])) end
		elseif self.Ping.Stutter > 0 and not airborne and rng:NextNumber() < self.Ping.Stutter * dt then
			self:Freeze(rng:NextNumber(0.06, 0.16))
		end
	else
		self.StuckPos = nil
	end
end

function Motor:StartRide(fn)
	self.Ride = fn
	if self.Bot.Animate then self.Bot.Animate.ForceIdle = true end
end
function Motor:StopRide()
	self.Ride = nil
	if self.RideConstraint then self.RideConstraint:Destroy(); self.RideConstraint = nil end
	if self.Bot.Animate then self.Bot.Animate.ForceIdle = false end
end

function Motor:Reset()
	self:Stop()
	self:StopRide()
	self.LagUntil = nil
	self.Jet.Want = 0; self.Jet.On = false; self.Jet.Constraint = nil; self.Jet.Charge = self:Pack().FlightTime; self.Jet.Locked = false
	self.Detour, self.Spin, self.Pulse, self.LookAt, self.LookYaw = nil, nil, nil, nil, nil
	self.ShiftLock = false
end

return Motor
