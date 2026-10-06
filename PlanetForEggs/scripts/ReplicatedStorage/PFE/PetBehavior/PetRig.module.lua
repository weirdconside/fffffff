--!nocheck
-- Procedural walk / idle animation for every pet rig, whatever its joints are called.
-- The pack's rigs name their parts "Cube.133", "Motormesh0021", "BoneMesh_003" and so on, so
-- joints are sorted by geometry instead of by name: in the rest pose each Motor6D (or Bone) is
-- measured in model space (X right, Y up, -Z forward) and the direction from the joint to the
-- centre of everything hanging off it says what it is:
--   * pointing down and ending low  -> Leg (its children: Knee, then Foot)
--   * pointing back, behind centre  -> Tail (segments wave one after another)
--   * pointing forward/up, in front -> Head
--   * pointing sideways, far out    -> Wing / fin
-- Every rotation is made about the MODEL's axes (converted into each joint's own frame once), so
-- a leg swings forward/back no matter how the rig's joint frames are oriented. On top of the
-- limbs the whole body gets a gait: trot bob for four legs, waddle for two, hop for round
-- legless pets, a sway for snakes and fish, a gentle roll for flyers.
local PetRig = {}
PetRig.__index = PetRig

local XA, YA, ZA = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis

local NAMED = {
	{"wing", "Wing"}, {"fin", "Wing"}, {"tail", "Tail"}, {"head", "Head"}, {"neck", "Head"},
	{"calf", "Knee"}, {"lower", "Knee"}, {"paw", "Foot"}, {"foot", "Foot"}, {"femor", "Leg"}, {"thigh", "Leg"},
	{"upperarm", "Leg"}, {"upperleg", "Leg"}, {"arm", "Leg"}, {"leg", "Leg"},
}
local BODY_WORDS = {"body", "torso", "spine", "pelvis", "chest", "hips"}
local CONTROL_PREFIX = {"ik", "pole"}                         -- IK targets / pole bones: never animated
local ROOT_PREFIX = {"root", "pin", "main", "humanoidrootpart"}
local function byName(name, depth, count)
	local lower = string.lower(name)
	for _, word in ipairs(BODY_WORDS) do
		if string.find(lower, word, 1, true) then return "Body" end
	end
	for _, prefix in ipairs(CONTROL_PREFIX) do
		if string.sub(lower, 1, #prefix) == prefix then return "Body" end
	end
	if depth <= 1 then
		for _, prefix in ipairs(ROOT_PREFIX) do
			if string.sub(lower, 1, #prefix) == prefix then return "Body" end
		end
	end
	for _, pair in ipairs(NAMED) do
		if string.find(lower, pair[1], 1, true) then
			-- a "leg" carrying half the skeleton isn't one
			if (pair[2] == "Leg" or pair[2] == "Knee" or pair[2] == "Foot") and count > 8 then return nil end
			return pair[2]
		end
	end
	return nil
end

-- water pets swim: their "legs" are fins; the kraken's are tentacles
local SWIMMERS = {Catfish = true, Swordfish = true, WhaleShark = true, AlabasterWhale = true, Thresher = true, Orca = true,
	Parrotfish = true, Mosasaurus = true, Kraken = true}

-- model-space bounds of the visible parts
local function bounds(model, pivot)
	local lo, hi
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 0.95 and p.Name ~= "HumanoidRootPart" then
			local cf = pivot:ToObjectSpace(p.CFrame)
			local h = p.Size / 2
			for sx = -1, 1, 2 do
				for sy = -1, 1, 2 do
					for sz = -1, 1, 2 do
						local c = cf * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
						lo = lo and Vector3.new(math.min(lo.X, c.X), math.min(lo.Y, c.Y), math.min(lo.Z, c.Z)) or c
						hi = hi and Vector3.new(math.max(hi.X, c.X), math.max(hi.Y, c.Y), math.max(hi.Z, c.Z)) or c
					end
				end
			end
		end
	end
	lo = lo or Vector3.new(-1, 0, -1); hi = hi or Vector3.new(1, 2, 1)
	return {Min = lo, Max = hi, Size = hi - lo, Center = (lo + hi) / 2}
end

-- does this chain reach the floor? (legs do; fins, arms, ears and wings don't)
local function touchesFloor(e, b)
	-- bones stop at the ankle, part chains reach the sole
	return e.Low < b.Min.Y + b.Size.Y * (e.Bone and 0.4 or 0.15)
end

local function geometric(e, b)
	local d = e.Reach - e.Pos
	local size = b.Size
	local H = size.Y
	-- a leaf bone with nothing below it: only its place says anything
	if d.Magnitude < 1e-3 then
		if e.Pos.Y < b.Min.Y + H * 0.3 and math.abs(e.Pos.X - b.Center.X) > size.X * 0.15 then return "Leg" end
		return "Body"
	end
	if d.Magnitude < 0.08 * H and e.Extent < 0.25 * H then return "Body" end
	-- legs: a short chain that ends on the floor and doesn't point up (spider legs arch out first)
	if e.Count <= 6 and touchesFloor(e, b) and d.Y < d.Magnitude * 0.3 and e.Pos.Y > e.Low + H * 0.12 then return "Leg" end
	if math.abs(d.X) > (math.abs(d.Y) + math.abs(d.Z)) * 0.8 and math.abs(e.Reach.X - b.Center.X) > size.X * 0.28 then return "Wing" end
	if e.Pos.Z > b.Center.Z + size.Z * 0.1 and d.Z > 0 and d.Z > math.abs(d.X) then return "Tail" end
	if e.Pos.Z < b.Center.Z - size.Z * 0.08 and e.Reach.Y > b.Min.Y + H * 0.35
		and (d.Z < 0 or (d.Y > 0 and e.Pos.Y > b.Center.Y)) then return "Head" end
	-- a short chain hanging down that doesn't reach the floor: a fin / flipper / arm
	if e.Count <= 6 and d.Y < 0 and -d.Y > math.sqrt(d.X * d.X + d.Z * d.Z) * 0.6 then return "Arm" end
	return "Body"
end

local CHAIN = {Leg = "Knee", Knee = "Foot", Foot = "Foot", Wing = "Wing", Arm = "Arm"}

-- axes of the model expressed in a joint frame (rotation-only), so a rotation of `a` about the
-- model's X axis is CFrame.fromAxisAngle(entry.AX, a) in that joint's local space
local function axes(entry, frameInModel)
	local r = frameInModel.Rotation
	entry.AX = r:VectorToObjectSpace(XA)
	entry.AY = r:VectorToObjectSpace(YA)
	entry.AZ = r:VectorToObjectSpace(ZA)
end

local function classify(list, b)
	table.sort(list, function(a, c) return a.Depth < c.Depth end)
	for _, e in ipairs(list) do
		local parentKind = e.ParentEntry and e.ParentEntry.Kind
		local kind = parentKind and CHAIN[parentKind]
		local chained = kind ~= nil
		if not kind then
			local named = byName(e.Name, e.Depth, e.Count or 0)
			if named then
				kind = named
				if kind == "Knee" or kind == "Foot" then kind = (parentKind == "Leg" or parentKind == "Knee") and kind or "Leg" end
				-- a named leg that never reaches the floor is an arm / flipper
				if kind == "Leg" and not touchesFloor(e, b) then kind = "Arm" end
			else
				kind = geometric(e, b)
				-- heads and tails continue down their chain unless the geometry says otherwise
				if (parentKind == "Head" or parentKind == "Tail") and kind == "Body" then kind = parentKind; chained = true end
			end
		end
		e.Kind = kind
		e.Side = e.Pos.X < b.Center.X and -1 or 1
		e.Front = e.Pos.Z < b.Center.Z
		if e.ParentEntry and chained then
			e.Side, e.Front = e.ParentEntry.Side, e.ParentEntry.Front
			e.Segment = (e.ParentEntry.Segment or 0) + 1
		else
			e.Segment = 0
		end
	end
end

function PetRig.new(model, species, options)
	options = options or {}
	local self = setmetatable({Joints = {}, Bones = {}, Time = 0, Stride = 0, Blend = 0, Speed = 0, Moving = false,
		Species = species, Float = options.Float == true, Seed = options.Seed or 0}, PetRig)
	local pivot = model:GetPivot()
	local b = bounds(model, pivot)
	self.Bounds = b
	self.Height = math.max(0.5, b.Size.Y)

	-- Motor6D joints and what hangs off each of them
	local motors, byPart1, driven = {}, {}, {}
	for _, m in ipairs(model:GetDescendants()) do
		if m:IsA("Motor6D") and m.Part0 and m.Part1 then
			table.insert(motors, m); byPart1[m.Part1] = m
			driven[m.Part0] = driven[m.Part0] or {}
			table.insert(driven[m.Part0], m)
		end
	end
	-- parts welded onto a limb's part move with it (pets built from blocks: a leg's shin and foot)
	local welded = {}
	for _, w in ipairs(model:GetDescendants()) do
		if (w:IsA("Weld") or w:IsA("WeldConstraint")) and not w:IsA("Motor6D") and w.Part0 and w.Part1 and w.Part0 ~= w.Part1 then
			welded[w.Part0] = welded[w.Part0] or {}
			table.insert(welded[w.Part0], w.Part1)
		end
	end
	local reachCache = {}
	local function lowestOf(part)
		local cf = pivot:ToObjectSpace(part.CFrame)
		local h = part.Size / 2
		local low = math.huge
		for sx = -1, 1, 2 do for sy = -1, 1, 2 do for sz = -1, 1, 2 do
			low = math.min(low, (cf * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)).Y)
		end end end
		return low
	end
	local function reach(part, depth)
		local hit = reachCache[part]
		if hit then return hit[1], hit[2], hit[3], hit[4], hit[5] end
		local w = math.max(0.05, part.Size.Magnitude)
		local sum, total = pivot:PointToObjectSpace(part.Position) * w, w
		local extent, low, count = part.Size.Magnitude, lowestOf(part), 0
		for _, q in ipairs(welded[part] or {}) do
			if q.Transparency < 0.95 then
				local wq = math.max(0.05, q.Size.Magnitude)
				sum += pivot:PointToObjectSpace(q.Position) * wq; total += wq
				low = math.min(low, lowestOf(q))
				extent = math.max(extent, (q.Position - part.Position).Magnitude + q.Size.Magnitude / 2)
			end
		end
		if depth < 12 then
			for _, m in ipairs(driven[part] or {}) do
				local c, t, e, l, n = reach(m.Part1, depth + 1)
				sum += c * t; total += t; extent = math.max(extent, e); low = math.min(low, l); count += n + 1
			end
		end
		local centre = sum / total
		reachCache[part] = {centre, total, extent, low, count}
		return centre, total, extent, low, count
	end
	local entries = {}
	local function depthOf(m, guard)
		local parent = byPart1[m.Part0]
		if not parent or guard > 16 then return 0 end
		return depthOf(parent, guard + 1) + 1
	end
	for _, m in ipairs(motors) do
		local frame = pivot:ToObjectSpace(m.Part0.CFrame * m.C0)
		local centre, _, extent, low, count = reach(m.Part1, 0)
		local e = {Joint = m, Rest = m.C0, Name = m.Part1.Name, Pos = frame.Position, Reach = centre, Extent = extent, Depth = depthOf(m, 0),
			Low = low, Count = count}
		axes(e, frame)
		entries[m.Part1] = e
		table.insert(self.Joints, e)
	end
	for _, e in ipairs(self.Joints) do e.ParentEntry = entries[e.Joint.Part0] end

	-- skinned rigs: Bones (world pose rebuilt from the parent chain, works before replication settles)
	local boneWorld = {}
	local function worldOf(bone, guard)
		if boneWorld[bone] then return boneWorld[bone] end
		local parent = bone.Parent
		local base
		if parent and parent:IsA("Bone") and guard < 64 then base = worldOf(parent, guard + 1)
		elseif parent and parent:IsA("BasePart") then base = parent.CFrame
		else base = pivot end
		local cf = base * bone.CFrame
		boneWorld[bone] = cf
		return cf
	end
	local boneEntries = {}
	for _, bone in ipairs(model:GetDescendants()) do
		if bone:IsA("Bone") then
			local frame = pivot:ToObjectSpace(worldOf(bone, 0))
			local e = {Bone = bone, Name = bone.Name, Pos = frame.Position, Depth = 0, Extent = 0, Low = frame.Position.Y, Count = 0}
			axes(e, frame)
			boneEntries[bone] = e
			table.insert(self.Bones, e)
		end
	end
	for _, e in ipairs(self.Bones) do
		local parent = e.Bone.Parent
		e.ParentEntry = parent and boneEntries[parent]
		local depth, node = 0, e.ParentEntry
		while node and depth < 64 do depth += 1; node = node.ParentEntry end
		e.Depth = depth
		-- reach: the average of the bones below this one (or a step along the parent's direction)
		local sum, n = Vector3.zero, 0
		local low = e.Pos.Y
		for _, child in ipairs(e.Bone:GetDescendants()) do
			local ce = child:IsA("Bone") and boneEntries[child]
			if ce then sum += ce.Pos; n += 1; low = math.min(low, ce.Pos.Y) end
		end
		e.Low, e.Count = low, n
		if n > 0 then
			e.Reach = sum / n
			e.Extent = (e.Reach - e.Pos).Magnitude * 2
		elseif e.ParentEntry then
			e.Reach = e.Pos + (e.Pos - e.ParentEntry.Pos) * 0.5
			e.Extent = (e.Pos - e.ParentEntry.Pos).Magnitude
		else
			e.Reach = e.Pos
		end
	end
	-- skinned meshes: the bones drive the look; rigid Motor6D pieces on them stay put
	if #self.Bones >= 6 then self.Joints = {} end
	classify(self.Joints, b)
	classify(self.Bones, b)

	-- which gait fits this body
	local legs, tails, wings = 0, 0, 0
	for _, list in ipairs({self.Joints, self.Bones}) do
		for _, e in ipairs(list) do
			if e.Kind == "Leg" and e.Segment == 0 then legs += 1 end
			if e.Kind == "Tail" then tails += 1 end
			if e.Kind == "Wing" then wings += 1 end
		end
	end
	local size = b.Size
	if SWIMMERS[species] then
		for _, list in ipairs({self.Joints, self.Bones}) do
			for _, e in ipairs(list) do
				if e.Kind == "Leg" or e.Kind == "Knee" or e.Kind == "Foot" or e.Kind == "Arm" then
					e.Kind = species == "Kraken" and "Tail" or "Wing"
				end
			end
		end
		legs = 0
	end
	if self.Float then self.Gait = "Fly"
	elseif SWIMMERS[species] then self.Gait = "Slither"
	elseif legs >= 4 then self.Gait = "Quad"
	elseif legs >= 2 then self.Gait = "Biped"
	elseif tails >= 2 or size.Z > math.max(size.X, size.Y) * 1.6 then self.Gait = "Slither"
	else self.Gait = "Hop" end
	self.Legs, self.Tails, self.Wings = legs, tails, wings
	-- snakes and fish: every joint along the body (not the root) takes part in one travelling wave
	for _, list in ipairs({self.Joints, self.Bones}) do
		for _, e in ipairs(list) do
			e.Spine = self.Gait == "Slither" and e.Depth >= 1 and (e.Kind == "Head" or e.Kind == "Tail" or e.Kind == "Body")
		end
	end
	-- trot: diagonal legs together; bipeds alternate
	for _, list in ipairs({self.Joints, self.Bones}) do
		for _, e in ipairs(list) do
			if self.Gait == "Biped" then e.Phase = e.Side < 0 and 0 or math.pi
			else e.Phase = ((e.Side < 0) == e.Front) and 0 or math.pi end
		end
	end
	return self
end

function PetRig:SetMoving(moving, speed)
	self.Moving = moving; self.Speed = math.max(0, speed or 0)
end

local function turn(e, ax, ay, az)
	local cf = CFrame.identity
	if ax ~= 0 then cf = CFrame.fromAxisAngle(e.AX, ax) end
	if ay ~= 0 then cf = cf * CFrame.fromAxisAngle(e.AY, ay) end
	if az ~= 0 then cf = cf * CFrame.fromAxisAngle(e.AZ, az) end
	return cf
end

-- limb angles about the model axes for this frame
function PetRig:_angles(e)
	local s, b, t = self.Stride, self.Blend, self.Time
	local swing = math.sin(s + (e.Phase or 0))
	local kind = e.Kind
	if e.Spine then
		local length = math.max(1, self.Bounds.Size.Z)
		local wave = math.sin(t * (2 + 4 * b) - (e.Pos.Z / length) * 5)
		return 0, wave * (0.05 + 0.09 * b), 0
	end
	if kind == "Leg" then
		return swing * (self.Gait == "Biped" and 0.55 or 0.42) * b, 0, 0
	elseif kind == "Arm" then
		local k = (e.Segment or 0) > 0 and 0.5 or 1
		return (-swing * 0.35 * b + math.sin(t * 1.3 + e.Side) * 0.04) * k, 0, 0
	elseif kind == "Knee" then
		return -math.max(0, swing) * 0.5 * b, 0, 0
	elseif kind == "Foot" then
		return -swing * 0.18 * b, 0, 0
	elseif kind == "Tail" then
		local k = e.Segment or 0
		local wave = math.sin(t * (2.2 + 3 * b) + (self.Gait == "Slither" and s * 0.9 or 0) - k * 0.75)
		return 0.04 * math.sin(t * 1.7), wave * (0.12 + 0.16 * b + (self.Gait == "Slither" and 0.12 or 0)), 0
	elseif kind == "Head" then
		local nod = math.sin(s * 2) * 0.06 * b + math.sin(t * 2.1) * 0.025
		local look = math.sin(t * 0.55 + self.Seed) * 0.16 * (1 - b)
		return nod, look / math.max(1, (e.Segment or 0) + 1), 0
	elseif kind == "Wing" then
		local fly = self.Gait == "Fly"
		local speed = fly and 10 or (b > 0.5 and 5 or 2.4)
		local amount = fly and 0.55 or (b > 0.5 and 0.28 or 0.1)
		local flap = math.sin(t * speed + (e.Segment or 0) * 0.5) * amount
		return 0, 0, flap * e.Side * (e.Segment and e.Segment > 0 and 0.6 or 1)
	end
	return 0, 0, 0
end

-- advance; `extra` (optional) adds a performance on top: extra:Limb(kind, side) -> ax, ay, az
-- returns the whole-body offset to multiply onto the pet's pivot
function PetRig:Step(dt, extra)
	self.Time += dt
	self.Blend += ((self.Moving and 1 or 0) - self.Blend) * (1 - math.exp(-dt * 8))
	local rate = 5.5 + math.clamp(self.Speed, 0, 18) * 0.42
	self.Stride += dt * rate * math.max(self.Blend, 0.02)
	for _, e in ipairs(self.Joints) do
		if (e.Kind ~= "Body" or e.Spine) and e.Joint.Parent then
			local ax, ay, az = self:_angles(e)
			if extra then
				local ex, ey, ez = extra:Limb(e.Kind, e.Side)
				if ex then ax += ex; ay += ey; az += ez end
			end
			e.Joint.C0 = e.Rest * turn(e, ax, ay, az)
		end
	end
	for _, e in ipairs(self.Bones) do
		if (e.Kind ~= "Body" or e.Spine) and e.Bone.Parent then
			local ax, ay, az = self:_angles(e)
			if extra then
				local ex, ey, ez = extra:Limb(e.Kind, e.Side)
				if ex then ax += ex; ay += ey; az += ez end
			end
			e.Bone.Transform = turn(e, ax, ay, az)
		end
	end
	local s, b, t, h = self.Stride, self.Blend, self.Time, self.Height
	local breathe = CFrame.new(0, math.sin(t * 2.2 + self.Seed) * 0.012 * h, 0)
	local gait = self.Gait
	if gait == "Quad" then
		return breathe * CFrame.new(0, math.abs(math.sin(s)) * 0.05 * h * b, 0)
			* CFrame.Angles(math.sin(s * 2) * 0.03 * b, 0, math.sin(s) * 0.025 * b)
	elseif gait == "Biped" then
		return breathe * CFrame.new(0, math.abs(math.sin(s)) * 0.07 * h * b, 0)
			* CFrame.Angles(0, math.sin(s) * 0.06 * b, math.sin(s) * 0.1 * b)
	elseif gait == "Slither" then
		return breathe * CFrame.new(0, math.abs(math.sin(s * 0.9)) * 0.03 * h * b, 0)
			* CFrame.Angles(0, math.sin(s * 0.9) * 0.16 * b, math.sin(s * 0.9) * 0.05 * b)
	elseif gait == "Fly" then
		return breathe * CFrame.Angles(-0.12 * b + math.sin(t * 1.4) * 0.04, 0, math.sin(t * 1.1 + self.Seed) * 0.08)
	end
	-- Hop: little bounces while it moves, a squat-and-spring feel through the pitch
	local hop = math.abs(math.sin(s * 0.75))
	return breathe * CFrame.new(0, hop * 0.3 * h * b, 0) * CFrame.Angles((0.5 - hop) * 0.22 * b, 0, 0)
end

function PetRig:Destroy()
	for _, e in ipairs(self.Joints) do if e.Joint.Parent then e.Joint.C0 = e.Rest end end
	for _, e in ipairs(self.Bones) do if e.Bone.Parent then e.Bone.Transform = CFrame.identity end end
	self.Joints, self.Bones = {}, {}
end

-- a summary for tests / tuning: gait and how many joints of each kind were found
function PetRig:Describe()
	local counts = {}
	for _, list in ipairs({self.Joints, self.Bones}) do
		for _, e in ipairs(list) do counts[e.Kind] = (counts[e.Kind] or 0) + 1 end
	end
	return self.Gait, counts
end

return PetRig
