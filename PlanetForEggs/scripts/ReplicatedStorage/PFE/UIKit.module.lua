--!nocheck
-- Planet for Eggs UI kit, in the style of the top simulator games: Rubik text with heavy
-- outlines, image icons from the Steal an Egg pack, dark studded panels, chunky gradient
-- buttons and responsive scaling for phones, tablets, PC and console.
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local UI = {}
UI.C = {
	Ink = Color3.fromRGB(16, 14, 28), Night = Color3.fromRGB(24, 26, 44), Panel = Color3.fromRGB(34, 38, 62),
	Panel2 = Color3.fromRGB(52, 58, 92), Line = Color3.fromRGB(255, 255, 255), White = Color3.fromRGB(255, 255, 255),
	Soft = Color3.fromRGB(200, 206, 230), Muted = Color3.fromRGB(104, 110, 138),
	Red = Color3.fromRGB(255, 64, 84), Orange = Color3.fromRGB(255, 146, 38), Gold = Color3.fromRGB(255, 206, 40),
	Green = Color3.fromRGB(70, 222, 70), Teal = Color3.fromRGB(40, 222, 186), Blue = Color3.fromRGB(40, 160, 255),
	Purple = Color3.fromRGB(164, 88, 255), Pink = Color3.fromRGB(255, 96, 196), Cyan = Color3.fromRGB(64, 226, 255),
}
local C = UI.C
UI.Font = Enum.Font.GothamBlack
UI.Font2 = Enum.Font.GothamBold
UI.FontFace = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)        -- Rubik
UI.FontHeavy = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy)
UI.FontMedium = Font.new("rbxassetid://12187365977", Enum.FontWeight.SemiBold)

-- image icons (Steal an Egg pack)
local function asset(id) return "rbxassetid://" .. id end
UI.Icons = {
	Shop = asset(78361985857528), Basket = asset(121617452949660), Index = asset(123304429230258), Info = asset(121134984323508),
	Pets = asset(123463862448531), Paw = asset(134966319141278), Egg = asset(96783034607256), EggBig = asset(114108770349086),
	Upgrade = asset(70704302836010), Gift = asset(139767177148368), GiftPink = asset(99857006958479), Close = asset(71646319230388),
	Next = asset(96732642249054), Prev = asset(85529650612312), Robux = asset(119506408090345), Coin = asset(98021974486825),
	CoinGold = asset(126681064013470), Diamond = asset(115517396195730), Cash = asset(136274729853348), CashStack = asset(130591156585519),
	MoneyBag = asset(139742352093157), X2Coins = asset(116101397751784), Bolt = asset(136009667806465), Bolt2 = asset(132517874354610),
	Clover = asset(93631063284531), Shoe = asset(98890095051151), ShoeGold = asset(108143552406623), Hourglass = asset(99230515036762),
	Stopwatch = asset(96168190157761), Lock = asset(72318121063950), LockWhite = asset(135017205969565), Check = asset(92088790716861),
	Sunburst = asset(94777715473697), Starburst = asset(127793720919899), Studs = asset(131176354845909), Studs2 = asset(117164658961906),
	New = asset(17426548648), Dice = asset(91172938049818), Rainbow = asset(85288683002868), Chest = asset(112271178072366),
	GoldBars = asset(72452071576643), Sparkle = asset(75480296519177), Hand = asset(111955278473321), Notif = asset(95109671231611),
	Star = asset(121779632121547), Stars = asset(105563752815856), Potion = asset(70765759712258), Ticket = asset(120222769031450),
	Heart = asset(115988933043114), Pulse = asset(119275771957836), Wing = asset(101419934580189), Volcano = asset(139648796443816),
	IceCube = asset(106875368516160),
	-- cartoon upgrade pictures from the Creator Store (drawn in the same style as the pack's icons)
	Rocket = "rbxthumb://type=Asset&id=135880345374404&w=420&h=420",
	Helmet = "rbxthumb://type=Asset&id=18571602488&w=420&h=420",
	JetpackIcon = "rbxthumb://type=Asset&id=4811843180&w=420&h=420",
}

function UI.named(color)
	if typeof(color) == "Color3" then return color end
	return C[color] or C.Purple
end

function UI.new(class, props, parent)
	local object = Instance.new(class)
	for key, value in pairs(props or {}) do object[key] = value end
	if parent then object.Parent = parent end
	return object
end
function UI.round(object, radius)
	return UI.new("UICorner", {CornerRadius = typeof(radius) == "UDim" and radius or UDim.new(0, radius or 14)}, object)
end
function UI.stroke(object, thickness, color, transparency)
	return UI.new("UIStroke", {Thickness = thickness or 2, Color = color or C.Ink, Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round}, object)
end
function UI.gradient(object, top, bottom, rotation)
	return UI.new("UIGradient", {Color = ColorSequence.new(top, bottom), Rotation = rotation or 90}, object)
end
function UI.pad(object, all, h)
	return UI.new("UIPadding", {PaddingTop = UDim.new(0, all), PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, h or all), PaddingRight = UDim.new(0, h or all)}, object)
end
function UI.list(object, padding, horizontal, align)
	return UI.new("UIListLayout", {Padding = UDim.new(0, padding or 8), SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Top}, object)
end
function UI.tween(object, props, duration, style, direction)
	local tween = TweenService:Create(object, TweenInfo.new(duration or 0.18, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

-- outlined game text (white Rubik with a dark outline)
function UI.text(parent, text, size, pos, textSize, color, props)
	textSize = textSize or 20
	local label = UI.new("TextLabel", {BackgroundTransparency = 1, BorderSizePixel = 0, Text = text or "", Size = size or UDim2.fromScale(1, 1),
		Position = pos or UDim2.new(), FontFace = textSize >= 26 and UI.FontHeavy or UI.FontFace, TextSize = textSize, TextColor3 = color or C.White,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = true, ZIndex = 4,
		RichText = true}, parent)
	UI.new("UIStroke", {Thickness = math.clamp(textSize / 9, 1.5, 4.5), Color = C.Ink, Transparency = 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, LineJoinMode = Enum.LineJoinMode.Round}, label)
	if props then for k, v in pairs(props) do label[k] = v end end
	return label
end

-- big tilted title that overlaps a panel's top edge (simulator-game signature)
function UI.title(parent, text, pos, textSize)
	local label = UI.text(parent, text, UDim2.fromOffset(520, (textSize or 44) + 12), pos or UDim2.fromOffset(-10, -34), textSize or 44)
	label.Name = "Title"; label.TextWrapped = false; label.Rotation = -3; label.ZIndex = 40
	label.FontFace = UI.FontHeavy
	local stroke = label:FindFirstChildOfClass("UIStroke"); if stroke then stroke.Thickness = math.clamp((textSize or 44) / 9, 3, 6) end
	return label
end

function UI.icon(parent, key, size, pos, props)
	local image = UI.new("ImageLabel", {Name = "Icon", BackgroundTransparency = 1, Image = UI.Icons[key] or key or "", ScaleType = Enum.ScaleType.Fit,
		Size = size or UDim2.fromScale(1, 1), Position = pos or UDim2.new(), ZIndex = 6}, parent)
	if props then for k, v in pairs(props) do image[k] = v end end
	return image
end

-- soft rotating sunburst behind rewards
function UI.sunburst(parent, size, color, transparency)
	local burst = UI.new("ImageLabel", {Name = "Sunburst", BackgroundTransparency = 1, Image = UI.Icons.Sunburst, ImageColor3 = color or C.Gold,
		ImageTransparency = transparency or 0.35, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = size or UDim2.fromScale(1.6, 1.6),
		ZIndex = 3}, parent)
	UI._bursts = UI._bursts or {}
	table.insert(UI._bursts, burst)
	return burst
end

-- studded dark panel
function UI.panel(parent, size, pos, props)
	local frame = UI.new("Frame", {Size = size, Position = pos or UDim2.new(), BackgroundColor3 = C.Panel, BorderSizePixel = 0, ZIndex = 2}, parent)
	UI.round(frame, 20)
	UI.gradient(frame, Color3.fromRGB(58, 64, 102), Color3.fromRGB(26, 28, 50))
	UI.stroke(frame, 4, C.Ink)
	local studs = UI.new("ImageLabel", {Name = "Studs", BackgroundTransparency = 1, Image = UI.Icons.Studs, ImageTransparency = 0.9,
		ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(64, 64), Size = UDim2.fromScale(1, 1), ZIndex = 2}, frame)
	UI.round(studs, 20)
	if props then for k, v in pairs(props) do frame[k] = v end end
	return frame
end

-- coloured card (rarity tiles, shop offers)
function UI.card(parent, color, size, pos, name)
	color = UI.named(color)
	local frame = UI.new("Frame", {Name = name or "Card", Size = size, Position = pos or UDim2.new(), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, ZIndex = 3}, parent)
	UI.round(frame, 16)
	UI.gradient(frame, color:Lerp(C.White, 0.18), color:Lerp(C.Ink, 0.42))
	UI.stroke(frame, 3, C.Ink)
	local studs = UI.new("ImageLabel", {Name = "Studs", BackgroundTransparency = 1, Image = UI.Icons.Studs, ImageTransparency = 0.88,
		ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(48, 48), Size = UDim2.fromScale(1, 1), ZIndex = 3}, frame)
	UI.round(studs, 16)
	return frame
end

-- interface sounds (Steal an Egg pack)
local SoundService = game:GetService("SoundService")
local sfx = {}
local function sfxPlay(name, id, volume, speed)
	if not RunService:IsClient() then return end
	local s = sfx[name]
	if not s then
		s = Instance.new("Sound")
		s.Name = "PFE_UI_" .. name; s.SoundId = id; s.Volume = volume; s.PlaybackSpeed = speed or 1
		s.Parent = SoundService
		sfx[name] = s
	end
	s.TimePosition = 0
	s:Play()
end
function UI.click() sfxPlay("Click", "rbxassetid://115437212690964", 0.5) end
function UI.hover() sfxPlay("Hover", "rbxassetid://126006309206939", 0.6, 0.96) end

local function pressFeedback(button, scale)
	button.Activated:Connect(function() if not button:GetAttribute("Disabled") then UI.click() end end)
	button.MouseButton1Down:Connect(function()
		if not button:GetAttribute("Disabled") then UI.tween(scale, {Scale = (button:GetAttribute("BaseScale") or 1) * 0.92}, 0.07) end
	end)
	local function release() UI.tween(scale, {Scale = button:GetAttribute("BaseScale") or 1}, 0.25, Enum.EasingStyle.Back) end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	button.MouseEnter:Connect(function()
		if not button:GetAttribute("Disabled") and not UserInputService.TouchEnabled then
			UI.tween(scale, {Scale = (button:GetAttribute("BaseScale") or 1) * 1.06}, 0.18, Enum.EasingStyle.Back)
			UI.hover()
		end
	end)
	button.SelectionGained:Connect(function() UI.tween(scale, {Scale = 1.06}, 0.15) end)
	button.SelectionLost:Connect(function() UI.tween(scale, {Scale = 1}, 0.15) end)
end
UI.pressFeedback = pressFeedback

-- chunky gradient button with a darker lip underneath
function UI.button(parent, text, color, size, pos, callback, props)
	color = UI.named(color)
	local holder = UI.new("TextButton", {Name = (props and props.Name) or "Button", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
		Size = size, Position = pos or UDim2.new(), ZIndex = 5, Selectable = true}, parent)
	local scale = UI.new("UIScale", {}, holder)
	local lip = UI.new("Frame", {Name = "Lip", BackgroundColor3 = color:Lerp(C.Ink, 0.5), BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.fromOffset(0, 4), ZIndex = 5}, holder)
	UI.round(lip, 12); UI.stroke(lip, 3, C.Ink)
	local face = UI.new("Frame", {Name = "Face", BackgroundColor3 = C.White, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0), ZIndex = 6}, holder)
	UI.round(face, 12); UI.stroke(face, 3, C.Ink)
	local grad = UI.gradient(face, color:Lerp(C.White, 0.28), color:Lerp(C.Ink, 0.08))
	local gloss = UI.new("Frame", {Name = "Gloss", BackgroundColor3 = C.White, BackgroundTransparency = 0.72, BorderSizePixel = 0,
		Size = UDim2.new(1, -12, 0.3, 0), Position = UDim2.fromOffset(6, 4), ZIndex = 7}, face)
	UI.round(gloss, 8)
	UI.new("UIGradient", {Transparency = NumberSequence.new(0.1, 1), Rotation = 90}, gloss)
	local caption = UI.text(face, text, UDim2.new(1, -12, 1, -6), UDim2.fromOffset(6, 3), (props and props.TextSize) or 22, C.White)
	caption.Name = "Caption"; caption.TextXAlignment = Enum.TextXAlignment.Center; caption.ZIndex = 8
	caption.TextScaled = true; caption.TextWrapped = false
	UI.new("UITextSizeConstraint", {MaxTextSize = (props and props.TextSize) or 24, MinTextSize = 9}, caption)
	if props and props.Icon then
		-- a square icon, 70% of the button's height, on the left; the price / text in the very middle of the
		-- button (the same margin on both sides, so it never runs under the icon)
		local icon = UI.icon(face, props.Icon, UDim2.fromScale(0.7, 0.7), UDim2.new(0, 10, 0.15, 0), {ZIndex = 8,
			SizeConstraint = Enum.SizeConstraint.RelativeYY})
		caption.Position = UDim2.new(0.22, 0, 0, 3); caption.Size = UDim2.new(0.56, 0, 1, -6)
		caption.TextXAlignment = Enum.TextXAlignment.Center
		local function fit()
			local w = icon.AbsoluteSize.X
			local total = face.AbsoluteSize.X
			if w <= 1 then return end
			local pad = w + 14
			if total >= pad * 2 + 30 then
				caption.Position = UDim2.new(0, pad, 0, 3); caption.Size = UDim2.new(1, -pad * 2, 1, -6)
			elseif total > w + 40 then -- (a narrow button: centred in what the icon leaves)
				caption.Position = UDim2.new(0, pad, 0, 3); caption.Size = UDim2.new(1, -(w + 22), 1, -6)
			end
		end
		icon:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		task.defer(fit)
	end
	holder:SetAttribute("Color", color)
	pressFeedback(holder, scale)
	holder.Activated:Connect(function()
		if holder:GetAttribute("Disabled") then return end
		if callback then callback() end
	end)
	if props then for k, v in pairs(props) do if k ~= "TextSize" and k ~= "Name" and k ~= "Icon" then holder[k] = v end end end
	return holder, caption, grad
end

function UI.setButtonColor(button, color)
	color = UI.named(color)
	local face = button:FindFirstChild("Face"); local lip = button:FindFirstChild("Lip")
	if face then
		local grad = face:FindFirstChildOfClass("UIGradient")
		if grad then grad.Color = ColorSequence.new(color:Lerp(C.White, 0.28), color:Lerp(C.Ink, 0.08)) end
	end
	if lip then lip.BackgroundColor3 = color:Lerp(C.Ink, 0.5) end
	button:SetAttribute("Color", color)
end
function UI.disable(button, disabled)
	button:SetAttribute("Disabled", disabled == true)
	button.Selectable = not disabled
	UI.setButtonColor(button, disabled and C.Muted or (button:GetAttribute("EnabledColor") or button:GetAttribute("Color")))
end
function UI.enableColor(button, color)
	button:SetAttribute("EnabledColor", UI.named(color))
end

-- red square close button from the pack
function UI.closeButton(parent, callback, size, pos)
	local button = UI.new("ImageButton", {Name = "Close", BackgroundTransparency = 1, Image = UI.Icons.Close, ScaleType = Enum.ScaleType.Fit,
		Size = size or UDim2.fromOffset(58, 58), Position = pos or UDim2.new(1, -30, 0, -22), ZIndex = 45}, parent)
	local scale = UI.new("UIScale", {}, button)
	pressFeedback(button, scale)
	button.Activated:Connect(function() if callback then callback() end end)
	return button
end

-- HUD menu button: big image icon with the caption across its bottom edge
function UI.tile(parent, iconKey, caption, color, size, callback, name)
	color = UI.named(color)
	local button = UI.new("TextButton", {Name = name or caption, Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
		Size = size or UDim2.fromOffset(76, 76), ZIndex = 5, Selectable = true}, parent)
	local scale = UI.new("UIScale", {}, button)
	local face = UI.new("Frame", {Name = "Face", BackgroundColor3 = C.White, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 5}, button)
	UI.round(face, 18); UI.stroke(face, 3.5, C.Ink)
	UI.gradient(face, color:Lerp(C.White, 0.3), color:Lerp(C.Ink, 0.2))
	local studs = UI.new("ImageLabel", {Name = "Studs", BackgroundTransparency = 1, Image = UI.Icons.Studs, ImageTransparency = 0.8,
		ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(38, 38), Size = UDim2.fromScale(1, 1), ZIndex = 5}, face)
	UI.round(studs, 18)
	local icon = UI.icon(face, iconKey, UDim2.fromScale(0.86, 0.86), UDim2.fromScale(0.07, 0.0), {ZIndex = 7})
	icon.Rotation = -6
	local label = UI.text(button, caption, UDim2.new(1, 16, 0, 24), UDim2.new(0, -8, 1, -18), 19)
	label.Name = "Caption"; label.TextXAlignment = Enum.TextXAlignment.Center; label.ZIndex = 8; label.TextWrapped = false
	local badge = UI.new("ImageLabel", {Name = "Badge", BackgroundTransparency = 1, Image = UI.Icons.Notif, Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -18, 0, -10), Visible = false, ZIndex = 9}, button)
	local badgeText = UI.new("TextLabel", {BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), Visible = false}, badge)
	pressFeedback(button, scale)
	button.Activated:Connect(function() if callback then callback() end end)
	return button, badge, badgeText
end

-- progress bar: dark track, glossy gradient fill
function UI.bar(parent, size, pos, color, back)
	local track = UI.new("Frame", {Name = "Bar", Size = size, Position = pos or UDim2.new(), BackgroundColor3 = back or C.Ink,
		BackgroundTransparency = 0.1, BorderSizePixel = 0, ZIndex = 4, ClipsDescendants = true}, parent)
	UI.round(track, 100)
	UI.stroke(track, 3, C.Ink)
	local fill = UI.new("Frame", {Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.White, BorderSizePixel = 0, ZIndex = 5}, track)
	UI.round(fill, 100)
	local grad = UI.gradient(fill, UI.named(color):Lerp(C.White, 0.3), UI.named(color):Lerp(C.Ink, 0.1))
	local shine = UI.new("Frame", {BackgroundColor3 = C.White, BackgroundTransparency = 0.62, BorderSizePixel = 0, Size = UDim2.new(1, -10, 0.3, 0),
		Position = UDim2.new(0, 5, 0.12, 0), ZIndex = 6}, fill)
	UI.round(shine, 100)
	local function set(value, newColor)
		UI.tween(fill, {Size = UDim2.fromScale(math.clamp(value, 0, 1), 1)}, 0.25)
		if newColor then grad.Color = ColorSequence.new(UI.named(newColor):Lerp(C.White, 0.3), UI.named(newColor):Lerp(C.Ink, 0.1)) end
	end
	return track, set, fill
end

function UI.pill(parent, text, color, size, pos, textSize)
	local frame = UI.new("Frame", {Size = size, Position = pos or UDim2.new(), BackgroundColor3 = UI.named(color), BorderSizePixel = 0, ZIndex = 4}, parent)
	UI.round(frame, 100); UI.stroke(frame, 2.5, C.Ink)
	local label = UI.text(frame, text, UDim2.new(1, -14, 1, -4), UDim2.fromOffset(7, 2), textSize or 16)
	label.TextXAlignment = Enum.TextXAlignment.Center; label.ZIndex = 5
	label.TextScaled = true; label.TextWrapped = false
	UI.new("UITextSizeConstraint", {MaxTextSize = textSize or 16, MinTextSize = 8}, label)
	return frame, label
end

-- Robux price: icon + number
function UI.price(parent, amount, size, pos)
	local holder = UI.new("Frame", {Name = "Price", BackgroundTransparency = 1, Size = size or UDim2.fromOffset(120, 30), Position = pos or UDim2.new(), ZIndex = 8}, parent)
	UI.list(holder, 4, true, Enum.HorizontalAlignment.Center).VerticalAlignment = Enum.VerticalAlignment.Center
	local icon = UI.icon(holder, "Robux", UDim2.fromScale(0, 0.9), nil, {ZIndex = 9})
	UI.new("UIAspectRatioConstraint", {AspectRatio = 1}, icon)
	icon.Size = UDim2.new(0, 22, 0, 22)
	local label = UI.text(holder, tostring(amount), UDim2.new(0, 80, 1, 0), nil, 22)
	label.AutomaticSize = Enum.AutomaticSize.X; label.Size = UDim2.new(0, 0, 1, 0); label.TextWrapped = false; label.ZIndex = 9
	return holder, label
end

-- Gradient orb used for planets in the tracker
function UI.orb(parent, size, pos, c1, c2, accent, ring)
	local orb = UI.new("Frame", {Name = "Orb", Size = size, Position = pos or UDim2.new(), BackgroundColor3 = C.White, BorderSizePixel = 0, ZIndex = 5}, parent)
	UI.new("UIAspectRatioConstraint", {AspectRatio = 1}, orb)
	UI.round(orb, UDim.new(0.5, 0))
	UI.new("UIGradient", {Color = ColorSequence.new({ColorSequenceKeypoint.new(0, c1:Lerp(C.White, 0.35)), ColorSequenceKeypoint.new(0.45, c1),
		ColorSequenceKeypoint.new(1, c2:Lerp(C.Ink, 0.35))}), Rotation = 135}, orb)
	local shade = UI.new("Frame", {Name = "Shade", BackgroundColor3 = C.Ink, BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), ZIndex = 6}, orb)
	UI.round(shade, UDim.new(0.5, 0))
	UI.new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 0.2)}), Rotation = 45}, shade)
	local spot = UI.new("Frame", {Name = "Spot", BackgroundColor3 = C.White, BackgroundTransparency = 0.55, Size = UDim2.fromScale(0.28, 0.2),
		Position = UDim2.fromScale(0.2, 0.16), Rotation = -30, ZIndex = 7}, orb)
	UI.round(spot, UDim.new(0.5, 0))
	local glow = UI.stroke(orb, 2, accent or c1, 0.25)
	glow.Name = "Glow"
	if ring then
		local band = UI.new("Frame", {Name = "Ring", BackgroundColor3 = accent or c1, BackgroundTransparency = 0.25, AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(1.6, 0.16), Position = UDim2.fromScale(0.5, 0.52), Rotation = -18, ZIndex = 8}, orb)
		UI.round(band, UDim.new(0.5, 0))
	end
	return orb
end

-- ---------------------------------------------------------------- viewports
local viewports = {}
local function visibleOnScreen(object)
	local node = object
	while node do
		if node:IsA("GuiObject") and not node.Visible then return false end
		if node:IsA("LayerCollector") then return node.Enabled end
		node = node.Parent
	end
	return false
end
function UI.viewport(parent, template, size, pos, opts)
	opts = opts or {}
	local view = UI.new("ViewportFrame", {Name = "ModelPreview", BackgroundTransparency = 1, Size = size, Position = pos or UDim2.new(),
		Ambient = Color3.fromRGB(190, 190, 205), LightColor = Color3.fromRGB(255, 252, 240), LightDirection = Vector3.new(-0.5, -1, -0.7), ZIndex = 6}, parent)
	if not template then return view end
	local world = UI.new("WorldModel", {}, view)
	local clone = template:Clone()
	local wrapper = clone
	if not clone:IsA("Model") then wrapper = UI.new("Model", {}, world); clone.Parent = wrapper end
	for _, d in ipairs(wrapper:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false
		elseif d:IsA("LuaSourceContainer") or d:IsA("LayerCollector") or d:IsA("ProximityPrompt") or d:IsA("ParticleEmitter") then d:Destroy() end
	end
	wrapper.Parent = world
	if opts.Prepare then opts.Prepare(wrapper) end
	-- frame only what is visible (hitboxes / root parts are invisible)
	local lo, hi
	for _, part in ipairs(wrapper:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 0.95 then
			local c, s = part.CFrame, part.Size * 0.5
			for _, corner in ipairs({Vector3.new(1, 1, 1), Vector3.new(-1, 1, 1), Vector3.new(1, -1, 1), Vector3.new(1, 1, -1),
				Vector3.new(-1, -1, 1), Vector3.new(-1, 1, -1), Vector3.new(1, -1, -1), Vector3.new(-1, -1, -1)}) do
				local p = c:PointToWorldSpace(s * corner)
				lo = lo and lo:Min(p) or p; hi = hi and hi:Max(p) or p
			end
		end
	end
	local center, bounds
	if lo then center, bounds = (lo + hi) * 0.5, hi - lo else local cf, b = wrapper:GetBoundingBox(); center, bounds = cf.Position, b end
	local camera = UI.new("Camera", {FieldOfView = 30}, view)
	view.CurrentCamera = camera
	table.insert(viewports, {object = view, camera = camera, center = center, bounds = bounds, spin = opts.Spin ~= false,
		phase = math.random() * 6.28, yaw = opts.Yaw or 0.5, silhouette = opts.Silhouette})
	if opts.Silhouette then
		view.ImageColor3 = Color3.fromRGB(12, 12, 24)
		view.Ambient = Color3.new(0, 0, 0); view.LightColor = Color3.new(0, 0, 0)
	end
	return view
end

local clock, visClock = 0, 0
RunService.RenderStepped:Connect(function(dt)
	clock += dt
	visClock += dt
	-- (v36) the walk up the tree to see whether a preview is on screen runs 5 times a second, not every frame
	local recheck = visClock >= 0.2
	if recheck then visClock = 0 end
	for i = #viewports, 1, -1 do
		local entry = viewports[i]
		if not entry.object.Parent then
			table.remove(viewports, i)
			continue
		end
		-- a still preview is only looked at on the recheck ticks
		if not entry.spin and not recheck and entry.framedAt then continue end
		if recheck or entry.visible == nil then entry.visible = visibleOnScreen(entry.object) end
		local abs = entry.object.AbsoluteSize
		-- a still preview only needs framing once (and again when its size changes)
		if entry.visible and (entry.spin or entry.framedAt ~= abs) then
			entry.framedAt = abs
			local aspect = math.max(0.4, abs.X / math.max(1, abs.Y))
			local radius = math.max(entry.bounds.Y, entry.bounds.X / aspect, entry.bounds.Z / aspect) * 0.5
			local distance = radius / math.tan(math.rad(15)) * 1.2 + entry.bounds.Z * 0.3
			local angle = entry.spin and (math.sin(clock * 0.8 + entry.phase) * 0.55 + 0.35) or entry.yaw
			entry.camera.CFrame = CFrame.lookAt(entry.center + Vector3.new(math.sin(angle) * distance, distance * 0.22, -math.cos(angle) * distance), entry.center)
		end
	end
end)

-- sunbursts spin slowly
RunService.Heartbeat:Connect(function(dt)
	-- cheap: only bursts tagged with the Spin attribute and on screen
	local list = UI._bursts
	if not list then return end
	for i = #list, 1, -1 do
		local burst = list[i]
		if burst.Parent then burst.Rotation = (burst.Rotation + dt * 18) % 360 else table.remove(list, i) end
	end
end)

-- ---------------------------------------------------------------- responsive scale
function UI.isTouch()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not GuiService:IsTenFootInterface()
end
function UI.isConsole()
	return GuiService:IsTenFootInterface()
end
-- Returns a scale factor for a UI designed at 1280x720. Phones get it a little smaller still:
-- the play area on a phone is small, the HUD must leave most of it free.
function UI.scaleFor(viewport)
	local s = math.min(viewport.X / 1280, viewport.Y / 720)
	if UI.isTouch() then s *= 1.05 end
	if UI.isConsole() then s *= 1.15 end
	return math.clamp(s, 0.42, 1.5)
end
-- the smallest scale any piece of HUD may shrink to on this device
function UI.minScale() return UI.isTouch() and 0.42 or 0.55 end
-- phones: keep the bottom row clear of the gesture bar / home indicator (not every device reports it)
function UI.bottomMargin() return UI.isTouch() and 10 or 0 end

return UI
