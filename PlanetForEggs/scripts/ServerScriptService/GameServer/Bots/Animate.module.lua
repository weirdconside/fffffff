--!nocheck
-- (v35) A bot's animations, exactly the way Roblox's own R15 "Animate" script plays a player's (a bot is an NPC: its
-- character has no LocalScript running, so the server plays them and they replicate like any NPC's):
--  * walk and run are both playing while it moves and blend by speed: runSpeed = speed / 16 * 1.25 / heightScale,
--    walk alone below 0.33, crossfading up to 0.66, run alone above, both sped up by runSpeed (at this game's walk
--    speeds the legs turn over fast, like everyone's) - the old bots played one stiff track at a fixed speed;
--  * idle picks its variant by weight (breathing 9 : look around 1) again every time the loop ends;
--  * jump for 0.31 s, then fall; climb / swim / sit; knocked off its feet (PlatformStand, getting up): nothing plays;
--  * a tool in the hand: "toolnone" (the arm held out) at Idle priority, and a swing is the tool's "toolanim"
--    StringValue ("Slash"), the very message a player's bat sends - toolslash at Action priority for 0.3 s;
--  * Frozen (a lag spike): the body stops but the tracks run on, as a laggy player's do on everyone else's screen;
--  * Overlay: one extra looped track on top (the treadmill run), like Treadmill.client's.
local Animate = {}
Animate.__index = Animate

local SMALL = 0.0001
local JUMP_TIME = 0.31

local function idOf(value)
	if type(value) == "number" then return "rbxassetid://" .. value end
	return tostring(value)
end

function Animate.new(model, humanoid, set)
	local self = setmetatable({Model = model, Humanoid = humanoid, Set = set, Tracks = {}, Pose = "Standing",
		Current = nil, CurrentTrack = nil, RunTrack = nil, AnimSpeed = 1, JumpTime = 0, ToolAnim = "None", ToolAnimTime = 0,
		ToolTrack = nil, ToolName = nil, Frozen = false, ForceIdle = false, Overlay = nil, Clock = 0}, Animate)
	local ok, animator = pcall(function()
		return humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	end)
	self.Animator = ok and animator or nil
	return self
end

-- the scale Animate uses to slow a tall avatar's stride (HipHeight against the 2-stud default, damped 40%)
function Animate:HeightScale()
	local h = self.Humanoid
	local ok, scale = pcall(function()
		if not h.AutomaticScalingEnabled then return 1 end
		return 1 + (h.HipHeight - 2) * 0.4 / 2
	end)
	return ok and math.max(0.3, scale) or 1
end

function Animate:Load(id)
	local key = idOf(id)
	local track = self.Tracks[key]
	if track then return track end
	if not self.Animator then return nil end
	local animation = Instance.new("Animation")
	animation.AnimationId = key
	local ok, result = pcall(function() return self.Animator:LoadAnimation(animation) end)
	if ok and result then
		self.Tracks[key] = result
		return result
	end
	return nil
end

local function roll(list)
	if type(list) ~= "table" then return list end
	local total = 0
	for _, entry in ipairs(list) do total += entry[2] end
	local r = math.random() * total
	for _, entry in ipairs(list) do
		r -= entry[2]
		if r <= 0 then return entry[1] end
	end
	return list[1][1]
end

function Animate:StopCore(fade)
	if self.CurrentTrack then pcall(function() self.CurrentTrack:Stop(fade) end) end
	if self.RunTrack then pcall(function() self.RunTrack:Stop(fade) end) end
	self.CurrentTrack, self.RunTrack, self.Current = nil, nil, nil
end

-- playAnimation(name, transitionTime): restarts nothing that is already playing
function Animate:Play(name, fade, forcedId)
	if not forcedId and self.Current == name and self.CurrentTrack and self.CurrentTrack.IsPlaying then return end
	local id = forcedId or roll(self.Set[name])
	if not id then return end
	local track = self:Load(id)
	if not track then return end
	if self.CurrentTrack and self.CurrentTrack ~= track then pcall(function() self.CurrentTrack:Stop(fade) end) end
	if self.RunTrack and name ~= "walk" then pcall(function() self.RunTrack:Stop(fade) end); self.RunTrack = nil end
	self.AnimSpeed = 1
	if not (self.CurrentTrack == track and track.IsPlaying) then pcall(function() track:Play(fade) end) end
	self.Current, self.CurrentTrack = name, track
	if name == "walk" then
		local run = self:Load(self.Set.run)
		if run then
			pcall(function() run:Play(fade, SMALL); run:AdjustWeight(SMALL) end)
			self.RunTrack = run
		end
		self.AnimSpeed = -1
	elseif name == "idle" and type(self.Set.idle) == "table" and #self.Set.idle > 1 then
		-- the next variant when this loop ends (Animate rolls again on its "End" keyframe)
		self.IdleHooked = self.IdleHooked or {}
		if not self.IdleHooked[track] then
			self.IdleHooked[track] = true
			local key = idOf(id)
			pcall(function()
				track.DidLoop:Connect(function()
					if self.Current ~= "idle" or self.CurrentTrack ~= track or self.Frozen then return end
					local nextId = roll(self.Set.idle)
					if idOf(nextId) ~= key then self:Play("idle", 0.15, nextId) end
				end)
			end)
		end
	end
end

-- setRunSpeed: the walk / run blend
function Animate:SetRunSpeed(speed)
	local runSpeed = speed * 1.25 / self:HeightScale()
	if math.abs(runSpeed - self.AnimSpeed) < 0.03 then return end
	self.AnimSpeed = runSpeed
	local walk, run = self.CurrentTrack, self.RunTrack
	if not walk then return end
	pcall(function()
		if not run then walk:AdjustSpeed(runSpeed); return end
		if runSpeed < 0.33 then
			walk:AdjustWeight(1); run:AdjustWeight(SMALL)
		elseif runSpeed < 0.66 then
			local w = (runSpeed - 0.33) / 0.33
			walk:AdjustWeight(1 - w + SMALL); run:AdjustWeight(w + SMALL)
		else
			walk:AdjustWeight(SMALL); run:AdjustWeight(1)
		end
		run:AdjustSpeed(runSpeed); walk:AdjustSpeed(runSpeed)
	end)
end

function Animate:SetSpeed(speed)
	if math.abs(speed - self.AnimSpeed) < 0.03 or not self.CurrentTrack then return end
	self.AnimSpeed = speed
	pcall(function() self.CurrentTrack:AdjustSpeed(speed) end)
end

-- tools: "toolnone" while holding one, the tool's own message for a swing
function Animate:PlayTool(name, fade, priority)
	if self.ToolName == name and self.ToolTrack and self.ToolTrack.IsPlaying then return end
	local track = self:Load(self.Set[name])
	if not track then return end
	if self.ToolTrack and self.ToolTrack ~= track then pcall(function() self.ToolTrack:Stop(fade) end) end
	pcall(function() track.Priority = priority; track:Play(fade) end)
	self.ToolTrack, self.ToolName = track, name
end
function Animate:StopTool()
	if self.ToolTrack then pcall(function() self.ToolTrack:Stop(0.1) end) end
	self.ToolTrack, self.ToolName = nil, nil
	self.ToolAnim = "None"; self.ToolAnimTime = 0
end

-- one looped track on top of everything (the treadmill run)
function Animate:SetOverlay(id, speed)
	if not id then
		if self.Overlay then pcall(function() self.Overlay:Stop(0.2) end) end
		self.Overlay = nil
		return
	end
	-- (v36) a track of its own: the walk/run blend uses the cached "run" track, and the idle that plays while the
	-- body is held on the belt stopped that shared track at once - the bot just stood on the treadmill
	self.OverlayTracks = self.OverlayTracks or {}
	local key = type(id) == "number" and ("rbxassetid://" .. id) or tostring(id)
	local track = self.OverlayTracks[key]
	if not track and self.Animator then
		local animation = Instance.new("Animation")
		animation.AnimationId = key
		local ok, result = pcall(function() return self.Animator:LoadAnimation(animation) end)
		if ok and result then track = result; self.OverlayTracks[key] = result end
	end
	if not track then return end
	if self.Overlay ~= track then
		if self.Overlay then pcall(function() self.Overlay:Stop(0.2) end) end
		pcall(function() track.Priority = Enum.AnimationPriority.Action; track.Looped = true; track:Play(0.2) end)
		self.Overlay = track
	end
	if speed then pcall(function() track:AdjustSpeed(speed) end) end
end

function Animate:Step(dt)
	local h = self.Humanoid
	if not h or not h.Parent or self.Frozen then return end
	self.Clock += dt
	self.JumpTime -= dt
	local root = self.Model:FindFirstChild("HumanoidRootPart")
	local velocity = root and root.AssemblyLinearVelocity or Vector3.zero
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	if root and root.Anchored then speed = 0 end
	local state = h:GetState()
	local S = Enum.HumanoidStateType
	local heightScale = self:HeightScale()
	if h.Health <= 0 or state == S.Dead then
		self.Pose = "Dead"
	elseif h.PlatformStand or state == S.PlatformStanding then
		self.Pose = "PlatformStanding"
	elseif state == S.GettingUp or state == S.FallingDown or state == S.Ragdoll or state == S.Physics then
		self.Pose = state == S.GettingUp and "GettingUp" or "FallingDown"
	elseif self.ForceIdle then
		self.Pose = "Standing"
		self:Play("idle", 0.2)
	elseif state == S.Seated then
		self.Pose = "Seated"
		self:Play("sit", 0.5)
	elseif state == S.Jumping then
		if self.Pose ~= "Jumping" then
			self:Play("jump", 0.1)
			self.JumpTime = JUMP_TIME
		end
		self.Pose = "Jumping"
	elseif state == S.Freefall then
		if self.JumpTime <= 0 then self:Play("fall", 0.2) end
		self.Pose = "FreeFall"
	elseif state == S.Climbing then
		self:Play("climb", 0.1)
		self:SetSpeed(math.abs(velocity.Y) / 5)
		self.Pose = "Climbing"
	elseif state == S.Swimming then
		if speed > 1 * heightScale then self:Play("swim", 0.4); self:SetSpeed(speed / 10) else self:Play("swimidle", 0.4) end
		self.Pose = "Standing"
	else
		-- Running / RunningNoPhysics / Landed: onRunning(speed)
		if speed > 0.75 * heightScale then
			self:Play("walk", 0.2)
			self:SetRunSpeed(speed / 16)
			self.Pose = "Running"
		else
			self:Play("idle", 0.2)
			self.Pose = "Standing"
		end
	end
	if self.Pose == "Dead" or self.Pose == "GettingUp" or self.Pose == "FallingDown" or self.Pose == "PlatformStanding" then
		self:StopCore(0.1)
	end
	-- the tool in the hand
	local tool = self.Model:FindFirstChildOfClass("Tool")
	if tool and tool:FindFirstChild("Handle") then
		local message = tool:FindFirstChild("toolanim")
		if message and message:IsA("StringValue") then
			self.ToolAnim = message.Value
			message.Parent = nil
			self.ToolAnimTime = self.Clock + 0.3
		end
		if self.Clock > self.ToolAnimTime then self.ToolAnimTime = 0; self.ToolAnim = "None" end
		if self.ToolAnim == "Slash" then self:PlayTool("toolslash", 0, Enum.AnimationPriority.Action)
		elseif self.ToolAnim == "Lunge" then self:PlayTool("toollunge", 0, Enum.AnimationPriority.Action)
		else self:PlayTool("toolnone", 0.1, Enum.AnimationPriority.Idle) end
	elseif self.ToolTrack then
		self:StopTool()
	end
end

function Animate:Destroy()
	self:StopCore(0)
	self:StopTool()
	self:SetOverlay(nil)
	for _, track in pairs(self.Tracks) do pcall(function() track:Destroy() end) end
	self.Tracks = {}
end

return Animate
