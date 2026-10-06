--!nocheck
-- Ten idle performances for pets, one per pet (picked from its id, so it is stable), played every
-- few seconds while the pet stands still: Bounce, Wiggle, Spin, Nod, Dance, Stretch, Flap,
-- LookAround, Sleepy and Flip. Each one moves the whole pet (works for every rig) and adds limb
-- angles on top of PetRig's walk/idle pose (heads, tails, legs, arms and wings, about the model's
-- own axes, for Motor6D and skinned rigs alike). Everything is local presentation only.
local PetAnimations = {}
PetAnimations.__index = PetAnimations
PetAnimations.Styles = {"Bounce", "Wiggle", "Spin", "Nod", "Dance", "Stretch", "Flap", "LookAround", "Sleepy", "Flip"}
local LENGTH = {Bounce = 1.4, Wiggle = 1.6, Spin = 1.0, Nod = 1.5, Dance = 3.2, Stretch = 2.2, Flap = 2.0, LookAround = 3.0, Sleepy = 4.0, Flip = 1.1}

local function ease(t) return t * t * (3 - 2 * t) end
local function bump(t) return math.sin(math.clamp(t, 0, 1) * math.pi) end

function PetAnimations.new(model, seed, height)
	local self = setmetatable({}, PetAnimations)
	self.Style = PetAnimations.Styles[(seed % #PetAnimations.Styles) + 1]
	self.Height = math.max(1, height or 3)
	self.Clock = 0
	self.Next = 1.5 + (seed % 7) * 0.6
	self.Playing = nil
	self.Blend = 0
	self.T = 0
	self.Model = model
	return self
end

-- advance the performance clock; call once per frame before PetRig:Step
function PetAnimations:Advance(dt, moving)
	self.Clock += dt
	if moving then
		self.Playing = nil
		self.Next = math.max(self.Next, self.Clock + 2)
	elseif not self.Playing and self.Clock >= self.Next then
		self.Playing = self.Clock
		if self.Style == "Sleepy" and self.Model and self.Model.Parent then
			local head = self.Model.PrimaryPart
			if head then
				local gui = Instance.new("BillboardGui")
				gui.Name = "PetZzz"; gui.Adornee = head; gui.Size = UDim2.fromOffset(60, 40); gui.StudsOffsetWorldSpace = Vector3.new(1.5, self.Height + 1, 0)
				gui.AlwaysOnTop = false; gui.MaxDistance = 80; gui.Parent = self.Model
				local text = Instance.new("TextLabel"); text.BackgroundTransparency = 1; text.Size = UDim2.fromScale(1, 1); text.Text = "Zzz"
				text.Font = Enum.Font.FredokaOne; text.TextScaled = true; text.TextColor3 = Color3.fromRGB(200, 220, 255); text.Parent = gui
				local stroke = Instance.new("UIStroke"); stroke.Thickness = 2; stroke.Color = Color3.fromRGB(20, 20, 40); stroke.Parent = text
				task.delay(LENGTH.Sleepy, function() gui:Destroy() end)
			end
		end
	end
	self.T = 0
	if self.Playing then
		self.T = (self.Clock - self.Playing) / LENGTH[self.Style]
		if self.T >= 1 then
			self.Playing = nil
			self.Next = self.Clock + 4 + (self.Clock * 7.13 % 5)
			self.T = 0
		end
	end
	local target = self.Playing and 1 or 0
	self.Blend += (target - self.Blend) * math.min(1, dt * 10)
end

-- extra angles (about the model's X, Y, Z axes) for a body part during the performance
function PetAnimations:Limb(kind, side)
	local b = self.Blend
	if b < 0.01 then return nil end
	local t, s = self.T, self.Style
	local x, y, z = 0, 0, 0
	if s == "Nod" and kind == "Head" then x = math.sin(t * math.pi * 6) * 0.35 * bump(t)
	elseif s == "Nod" and kind == "Tail" then y = math.sin(t * math.pi * 12) * 0.5
	elseif s == "LookAround" and kind == "Head" then y = math.sin(t * math.pi * 2) * 0.6
	elseif s == "Sleepy" and kind == "Head" then x = 0.45 * bump(t)
	elseif s == "Flap" and (kind == "Wing" or kind == "Arm") then z = side * math.sin(t * math.pi * 14) * 0.8 * bump(t)
	elseif s == "Flap" and kind == "Leg" then z = side * math.sin(t * math.pi * 14) * 0.25 * bump(t)
	elseif s == "Dance" and kind == "Head" then z = math.sin(t * math.pi * 8) * 0.25
	elseif s == "Dance" and (kind == "Leg" or kind == "Arm") then x = math.sin(t * math.pi * 8 + side) * 0.35
	elseif s == "Dance" and kind == "Tail" then y = math.sin(t * math.pi * 8) * 0.5
	elseif s == "Stretch" and kind == "Head" then x = -0.4 * bump(t)
	elseif s == "Stretch" and (kind == "Leg" or kind == "Arm") then x = 0.3 * bump(t) * side
	elseif (s == "Bounce" or s == "Spin" or s == "Flip") and (kind == "Leg" or kind == "Knee") then x = math.abs(math.sin(t * math.pi * 3)) * 0.4
	elseif s == "Wiggle" and kind == "Tail" then y = math.sin(t * math.pi * 10) * 0.6
	elseif s == "Wiggle" and kind == "Wing" then z = side * math.sin(t * math.pi * 10) * 0.3
	else return nil end
	return x * b, y * b, z * b
end

-- offset of the whole pet (relative to its pivot) for the current frame of the performance
function PetAnimations:Body()
	local b = self.Blend
	if b < 0.01 then return CFrame.identity end
	local h, s, t = self.Height, self.Style, self.T
	local cf = CFrame.identity
	if s == "Bounce" then
		cf = CFrame.new(0, math.abs(math.sin(t * math.pi * 3)) * h * 0.35, 0)
	elseif s == "Wiggle" then
		cf = CFrame.Angles(0, 0, math.sin(t * math.pi * 6) * 0.22 * bump(t))
	elseif s == "Spin" then
		cf = CFrame.new(0, bump(t) * h * 0.55, 0) * CFrame.Angles(0, ease(t) * math.pi * 2, 0)
	elseif s == "Nod" then
		cf = CFrame.Angles(math.sin(t * math.pi * 6) * 0.06 * bump(t), 0, 0)
	elseif s == "Dance" then
		cf = CFrame.new(0, math.abs(math.sin(t * math.pi * 8)) * h * 0.08, 0) * CFrame.Angles(0, math.sin(t * math.pi * 4) * 0.35, math.sin(t * math.pi * 8) * 0.12)
	elseif s == "Stretch" then
		cf = CFrame.new(0, bump(t) * h * 0.06, 0) * CFrame.Angles(-0.25 * bump(t), 0, 0)
	elseif s == "Flap" then
		cf = CFrame.new(0, bump(t) * h * 0.45 + math.sin(t * math.pi * 14) * h * 0.03, 0)
	elseif s == "LookAround" then
		cf = CFrame.Angles(0, math.sin(t * math.pi * 2) * 0.5, 0)
	elseif s == "Sleepy" then
		cf = CFrame.new(0, -bump(t) * h * 0.05, 0) * CFrame.Angles(0.08 * bump(t), 0, math.sin(t * math.pi * 3) * 0.05)
	elseif s == "Flip" then
		cf = CFrame.new(0, bump(t) * h * 0.9, 0) * CFrame.Angles(-ease(t) * math.pi * 2, 0, 0)
	end
	return CFrame.identity:Lerp(cf, b)
end

return PetAnimations
