--!nocheck
-- Modal menus: Robux shop, pets, egg index, upgrades (v28: + the treadmill), the trail shop (v28) and the
-- Studio test panel.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")

local EggForge = require(game:GetService("ReplicatedStorage"):WaitForChild("PFE"):WaitForChild("EggForge"))
local Menus = {}

local PASS_ICONS = {VIP = "Stars", DoubleMoney = "X2Coins", Lucky = "Clover", SuperSuit = "Bolt2", SpeedBoots = "ShoeGold",
	BigCargo = "Chest", RadarPro = "Hand"}
local PRODUCT_ICONS = {CreditsS = "Cash", CreditsM = "CashStack", CreditsL = "MoneyBag", Shield = "Lock", InstantHatch = "Hourglass",
	LuckBoost = "Dice", Oxygen = "Potion", Immortal5m = "Heart", Immortal15m = "Heart", Immortal30m = "Heart"}

function Menus.Init(store)
	local UI, Config, player, api = store.UI, store.Config, store.player, store.api
	local C = UI.C
	local PlanetMap = require(api:WaitForChild("PlanetMap"))
	local PetModels = require(api:WaitForChild("PetModels"))
	local assets = api:WaitForChild("UIAssets")

	local dim = UI.new("TextButton", {Name = "Dim", Text = "", AutoButtonColor = false, BackgroundColor3 = C.Ink, BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 30}, store.overlay)
	local modal = UI.panel(store.overlay, UDim2.fromOffset(840, 540), UDim2.fromScale(0.5, 0.53))
	modal.AnchorPoint = Vector2.new(0.5, 0.5); modal.Visible = false; modal.ZIndex = 31; modal.Name = "Menu"
	local modalScale = UI.new("UIScale", {}, modal)
	local title = UI.title(modal, "Shop", UDim2.fromOffset(-14, -40), 48)
	local wallet = UI.new("Frame", {Name = "Wallet", BackgroundTransparency = 1, Size = UDim2.fromOffset(220, 40), Position = UDim2.new(1, -300, 0, 12), ZIndex = 35}, modal)
	UI.icon(wallet, "Coin", UDim2.fromOffset(36, 36), UDim2.fromOffset(0, 2), {ZIndex = 36})
	local walletText = UI.text(wallet, "0", UDim2.new(1, -44, 1, 0), UDim2.fromOffset(42, 0), 26, C.Gold)
	walletText.ZIndex = 36; walletText.TextWrapped = false
	UI.closeButton(modal, function() Menus.Close() end, UDim2.fromOffset(64, 64), UDim2.new(1, -40, 0, -26))
	local tabBar = UI.new("Frame", {Name = "Tabs", BackgroundTransparency = 1, Size = UDim2.new(1, -40, 0, 44), Position = UDim2.fromOffset(20, 60), ZIndex = 33}, modal)
	UI.list(tabBar, 10, true)
	local scroll = UI.new("ScrollingFrame", {Name = "Content", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -24, 1, -130),
		Position = UDim2.fromOffset(12, 116), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8, ScrollBarImageColor3 = C.Soft, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 33}, modal)
	UI.pad(scroll, 8, 10)
	-- the index has its own two-pane view (Steal an Egg style): the list on the left, the pet on the right
	local indexView = UI.new("Frame", {Name = "IndexView", BackgroundTransparency = 1, Size = UDim2.new(1, -24, 1, -76),
		Position = UDim2.fromOffset(12, 64), Visible = false, ZIndex = 33}, modal)
	local indexPick = nil
	local fusePick = {}
	local RunService = game:GetService("RunService")
	local blur = UI.new("BlurEffect", {Name = "PFEMenuBlur", Size = 0}, Lighting)

	local active, tab, signature = nil, {}, ""
	local defs = {
		Shop = {Title = "Shop", Color = C.Green, Tabs = {"Passes", "Boosts"}},
		Pets = {Title = "Pets", Color = C.Orange},
		Index = {Title = "Index", Color = C.Blue},
		Fusion = {Title = "Fuse Eggs", Color = C.Pink},
		Codes = {Title = "Codes", Color = C.Cyan},
		Free = {Title = "Free VIP", Color = C.Gold},
		Daily = {Title = "Daily Rewards", Color = Color3.fromRGB(255, 120, 200)},
		Upgrades = {Title = "Upgrades", Color = C.Purple},
		Trails = {Title = "Trail Shop", Color = Color3.fromRGB(120, 90, 255)},
		Test = {Title = "Studio", Color = C.Muted},
	}

	local function clear()
		for _, child in ipairs(scroll:GetChildren()) do if not child:IsA("UIPadding") then child:Destroy() end end
		for _, child in ipairs(indexView:GetChildren()) do child:Destroy() end
		for _, child in ipairs(tabBar:GetChildren()) do if not child:IsA("UIListLayout") then child:Destroy() end end
	end
	local function section(text, order, color)
		local label = UI.text(scroll, text, UDim2.new(1, -8, 0, 36), nil, 26, color or C.White)
		label.LayoutOrder = order; label.TextWrapped = false
		return label
	end
	local function grid(order, cell, columns)
		local frame = UI.new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order}, scroll)
		UI.new("UIGridLayout", {CellSize = UDim2.new(1 / columns, -14, 0, cell), CellPadding = UDim2.fromOffset(14, 16), SortOrder = Enum.SortOrder.LayoutOrder}, frame)
		return frame
	end
	local columns = 3

	-- ---------------------------------------------------------------- prices
	local prices, loading = {}, {}
	local function fetchPrice(kind, id)
		if not id or id <= 0 or prices[id] or loading[id] then return end
		loading[id] = true
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id,
				kind == "Pass" and Enum.InfoType.GamePass or Enum.InfoType.Product)
			if ok and type(info) == "table" and info.PriceInRobux then prices[id] = info.PriceInRobux end
			if active == "Shop" then Menus.Render(true) end
		end)
	end
	local function buyButton(card, id, owned, onBuy)
		local configured = id and id > 0
		local label = owned and "OWNED" or (not configured and "SOON" or (prices[id] and tostring(prices[id]) or "BUY"))
		local button = UI.button(card, label, owned and C.Muted or C.Green, UDim2.new(1, -24, 0, 46), UDim2.new(0, 12, 1, -58), function()
			if configured and not owned then onBuy() end
		end, {TextSize = 24, Icon = (configured and not owned) and "Robux" or nil})
		if owned or not configured then UI.disable(button, true) end
		return button
	end
	local function iconWithBurst(card, key, color, size, pos)
		local holder = UI.new("Frame", {BackgroundTransparency = 1, Size = size, Position = pos, ZIndex = 5}, card)
		UI.sunburst(holder, UDim2.fromScale(1.5, 1.5), color, 0.55).ZIndex = 4
		UI.icon(holder, key, UDim2.fromScale(1, 1), nil, {ZIndex = 6})
		return holder
	end

	-- ---------------------------------------------------------------- renderers
	local renderers = {}
	function renderers.Shop(state)
		UI.list(scroll, 12)
		for _, product in ipairs(Config.ProductList) do
			if product.Kind == "LimitedEgg" then Menus.LimitedBanner(scroll, product, 0) end
		end
		if tab.Shop == "Passes" then
			local g = grid(1, 176, 2)
			for i, pass in ipairs(Config.GamePassList) do
				-- a pass won for a while in an alien ship can still be bought for good
				local owned = state.Passes and state.Passes[pass.Key] and not (state.TempPasses and state.TempPasses[pass.Key])
				local card = UI.card(g, pass.Color, UDim2.new(), nil, "Pass_" .. pass.Key)
				card.LayoutOrder = i
				iconWithBurst(card, PASS_ICONS[pass.Key] or "Star", C.White, UDim2.fromOffset(96, 96), UDim2.fromOffset(16, 14))
				local name = UI.text(card, pass.Name, UDim2.new(1, -140, 0, 34), UDim2.fromOffset(126, 12), 28)
				name.TextWrapped = false; name.TextScaled = true
				UI.new("UITextSizeConstraint", {MaxTextSize = 28}, name)
				local perks = UI.text(card, table.concat(pass.Perks, "\n"), UDim2.new(1, -140, 0, 56), UDim2.fromOffset(126, 48), 17, C.White)
				perks.TextYAlignment = Enum.TextYAlignment.Top
				fetchPrice("Pass", pass.Id)
				buyButton(card, pass.Id, owned, function() pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, pass.Id) end)
			end
		else
			local g = grid(1, 214, columns)
			for i, product in ipairs(Config.ProductList) do
				if product.Kind == "SkipGrowth" or product.Kind == "LimitedEgg" then continue end -- (skips: above growing eggs; the limited egg: its banner)
				local color = product.Kind == "Credits" and Color3.fromRGB(255, 196, 40) or product.Kind == "Shield" and C.Blue or product.Kind == "Luck" and C.Purple
					or product.Kind == "InstantHatch" and C.Pink or product.Kind == "Immortal" and Color3.fromRGB(255, 170, 40) or C.Teal
				local card = UI.card(g, color, UDim2.new(), nil, "Product_" .. product.Key)
				card.LayoutOrder = i
				iconWithBurst(card, PRODUCT_ICONS[product.Key] or "Gift", C.White, UDim2.fromOffset(76, 76), UDim2.new(0.5, -38, 0, 12))
				local name = UI.text(card, product.Name, UDim2.new(1, -16, 0, 28), UDim2.fromOffset(8, 92), 23)
				name.TextXAlignment = Enum.TextXAlignment.Center; name.TextWrapped = false; name.TextScaled = true
				UI.new("UITextSizeConstraint", {MaxTextSize = 23}, name)
				local detail
				if product.Kind == "Credits" then
					local amount = math.max(product.Min or 1000, math.floor((state.Income or 0) * 60 * (product.Minutes or 10)))
					detail = "+" .. Config.Format(amount)
				elseif product.Kind == "Shield" then detail = math.floor((product.Seconds or 900) / 60) .. " min"
				elseif product.Kind == "InstantHatch" then detail = "All eggs ready"
				elseif product.Kind == "Luck" then detail = "x2 luck " .. math.floor((product.Seconds or 1800) / 60) .. " min"
				elseif product.Kind == "Immortal" then detail = "Can't die · " .. math.floor((product.Seconds or 300) / 60) .. " min"
				else detail = "Full air" end
				local d = UI.text(card, detail, UDim2.new(1, -16, 0, 24), UDim2.fromOffset(8, 120), 19, C.Gold)
				d.TextXAlignment = Enum.TextXAlignment.Center
				fetchPrice("Product", product.Id)
				buyButton(card, product.Id, false, function() pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, player, product.Id) end)
			end
		end
	end

	-- (v28: `species` may be a pet record - a Chimera brings its own name, income and model)
	local function petCard(parent, order, species, opts)
		local info = Config.PetInfo(species)
		local rarity = Config.Rarities[info.Rarity]
		local card = UI.card(parent, rarity.Color, UDim2.new(), nil, opts.Name)
		card.LayoutOrder = order
		UI.viewport(card, PetModels.Template(species), UDim2.new(1, -12, 0, 118), UDim2.fromOffset(6, 6), {Silhouette = opts.Silhouette})
		local name = UI.text(card, opts.Title or info.Name, UDim2.new(1, -12, 0, 26), UDim2.fromOffset(6, 124), 21)
		name.TextXAlignment = Enum.TextXAlignment.Center; name.TextWrapped = false; name.TextScaled = true
		UI.new("UITextSizeConstraint", {MaxTextSize = 21}, name)
		if opts.TitleColor then name.TextColor3 = opts.TitleColor end
		local line = UI.text(card, opts.Line or info.Rarity, UDim2.new(1, -12, 0, 20), UDim2.fromOffset(6, 150), 16, rarity.Color:Lerp(C.White, 0.45))
		line.TextXAlignment = Enum.TextXAlignment.Center
		local earn = UI.text(card, opts.Earn or ("+" .. Config.Format(info.Income) .. "/s"), UDim2.new(1, -12, 0, 26), UDim2.fromOffset(6, 172), 21,
			opts.EarnColor or Color3.fromRGB(120, 255, 90))
		earn.TextXAlignment = Enum.TextXAlignment.Center
		return card
	end

	function renderers.Pets(state)
		UI.list(scroll, 12)
		local count = #(state.Pets or {})
		section(count .. " pets   +" .. Config.Format(state.Income or 0) .. "/s", 1)
		if count == 0 then
			section("Hatch an egg to get your first pet!", 2, C.Soft)
			return
		end
		local g = grid(3, 206, columns + 1)
		for i, pet in ipairs(state.Pets) do
			if i > 120 then break end
			local mutation = Config.Mutations[pet.Mutation or "Normal"]
			local info = Config.PetInfo(pet)
			local size = Config.SizeName(pet.Scale)
			petCard(g, i, pet, {Name = "Pet_" .. pet.Id,
				Title = (mutation and mutation.Name ~= "" and (mutation.Name .. " ") or "") .. info.Name,
				TitleColor = mutation and mutation.Id ~= "Normal" and mutation.Color or nil,
				Line = (info.Special and "SPECIAL" or info.Rarity) .. (size ~= "" and (" - " .. size) or "")
					.. (pet.Multiplier and ("  " .. Config.FormatMultiplier(pet.Multiplier)) or ""),
				Earn = "+" .. Config.Format(pet.Income) .. "/s",
				EarnColor = pet.Equipped and Color3.fromRGB(120, 255, 90) or C.Soft})
		end
	end

	-- ---------------------------------------------------------------- index (Steal an Egg style)
	-- Every pet, planet by planet: each planet's banner says where its eggs are found (planet, galaxy,
	-- how many you have), its pets below as tiles (a silhouette until hatched). The right-hand card
	-- shows the chosen pet: model, rarity, odds, income, size and the egg it comes from.
	local SIZE_CLASS = {{35, "Gargantuan"}, {20, "Titanic"}, {12, "Huge"}, {7, "Big"}, {0, "Small"}}
	local function sizeClass(rarity)
		local studs = Config.BasePetSize[rarity] or 5
		for _, row in ipairs(SIZE_CLASS) do if studs >= row[1] then return row[2], studs end end
		return "Small", studs
	end
	local function planetBanner(parent, planet, found, count, order)
		local galaxy = Config.Galaxies[planet.Galaxy]
		local banner = UI.new("Frame", {Name = "Banner_" .. planet.Id, BackgroundColor3 = C.White, Size = UDim2.new(1, -10, 0, 58),
			LayoutOrder = order, ZIndex = 34}, parent)
		UI.round(banner, 14)
		UI.gradient(banner, planet.Color:Lerp(C.White, 0.1), planet.Color2:Lerp(C.Ink, 0.2), 0)
		UI.stroke(banner, 3, C.Ink)
		UI.orb(banner, UDim2.fromOffset(46, 46), UDim2.fromOffset(8, 6), planet.Color, planet.Color2, planet.Accent, planet.Order % 3 == 0).ZIndex = 35
		local name = UI.text(banner, planet.Name, UDim2.new(1, -170, 0, 30), UDim2.fromOffset(62, 4), 26)
		name.TextWrapped = false; name.ZIndex = 36
		local where = UI.text(banner, (galaxy and galaxy.Name or "") .. "  ·  eggs found here", UDim2.new(1, -170, 0, 20), UDim2.fromOffset(62, 33), 15, C.Soft)
		where.TextWrapped = false; where.ZIndex = 36
		local tally = UI.text(banner, found .. "/" .. count, UDim2.fromOffset(92, 40), UDim2.new(1, -100, 0, 9), 28,
			found == count and Color3.fromRGB(120, 255, 90) or C.White)
		tally.TextXAlignment = Enum.TextXAlignment.Right; tally.ZIndex = 36
		return banner
	end
	-- every pet once (v27: an egg hatches one of several pets, a pet can come from several eggs): its eggs,
	-- each with the chance it hatches this pet, and how rare it is over all of its planet's eggs
	local function petEntries(state)
		local list, byPlanet = {}, {}
		local planetWeight = {}
		for _, planet in ipairs(Config.PlanetOrder) do
			local w = 0
			for _, egg in ipairs(Config.EggsOnPlanet(planet.Id)) do w += egg.Weight or 0 end
			planetWeight[planet.Id] = w
		end
		local bySpecies = {}
		for _, egg in ipairs(Config.EggCatalog) do
			if egg.Retired then
				-- (the retired Sakura Egg: its pets only show for those who have one)
				local any = false
				for _, drop in ipairs(egg.Drops or {}) do if state.DiscoveredPets and state.DiscoveredPets[drop[1]] then any = true end end
				if not any then continue end
			end
			local total = 0
			for _, drop in ipairs(egg.Drops or {}) do total += drop[2] end
			for _, drop in ipairs(egg.Drops or {}) do
				local sp = drop[1]
				local pet = Config.Pets[sp]
				if pet then
					local entry = bySpecies[sp]
					if not entry then
						local planet = Config.Planets[pet.Planet or ""]
						entry = {Species = sp, Pet = pet, Planet = planet, Limited = egg.Limited, Eggs = {}, P = 0,
							Known = state.DiscoveredPets and state.DiscoveredPets[sp] == true}
						bySpecies[sp] = entry
						table.insert(list, entry)
						local key = planet and planet.Id or "Limited"
						byPlanet[key] = byPlanet[key] or {}
						table.insert(byPlanet[key], entry)
					end
					local chance = drop[2] / math.max(0.001, total)
					table.insert(entry.Eggs, {Egg = egg, Chance = chance,
						Seen = state.DiscoveredEggs and state.DiscoveredEggs[egg.Id] == true})
					if egg.Limited then
						entry.P += chance
					else
						entry.P += (egg.Weight or 0) / math.max(0.001, planetWeight[egg.Planet] or 1) * chance
					end
				end
			end
		end
		for _, entry in ipairs(list) do
			table.sort(entry.Eggs, function(x, y) return x.Chance > y.Chance end)
			entry.Odds = 1 / math.max(1e-9, entry.P)
		end
		for _, entries in pairs(byPlanet) do
			table.sort(entries, function(x, y)
				local tx, ty = x.Pet.Tier or 1, y.Pet.Tier or 1
				if tx ~= ty then return tx < ty end
				return x.Odds < y.Odds
			end)
		end
		return list, byPlanet, bySpecies
	end
	Menus.PetEntries = petEntries
	function renderers.Index(state)
		local list_, byPlanet, bySpecies = petEntries(state)
		local total, found = #list_, 0
		for _, e in ipairs(list_) do if e.Known then found += 1 end end
		-- the progress bar across the top
		local head = UI.new("Frame", {Name = "IndexProgress", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), ZIndex = 34}, indexView)
		local caption = UI.text(head, "Collected " .. found .. " / " .. total, UDim2.fromOffset(230, 34), nil, 24)
		caption.TextWrapped = false; caption.ZIndex = 35
		local _, setBar = UI.bar(head, UDim2.new(1, -250, 0, 24), UDim2.fromOffset(240, 5), C.Blue)
		setBar(found / math.max(1, total))
		-- the list
		local list = UI.new("ScrollingFrame", {Name = "IndexList", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(0.6, -6, 1, -42),
			Position = UDim2.fromOffset(0, 42), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8,
			ScrollBarImageColor3 = C.Soft, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 34}, indexView)
		UI.list(list, 8)
		UI.pad(list, 4, 4)
		-- the card
		local card = UI.new("Frame", {Name = "IndexInfo", BackgroundTransparency = 1, Size = UDim2.new(0.4, -6, 1, -42),
			Position = UDim2.new(0.6, 6, 0, 42), ZIndex = 34}, indexView)
		local function showInfo(entry)
			for _, child in ipairs(card:GetChildren()) do child:Destroy() end
			if not entry then return end
			indexPick = entry.Species
			local pet, planet = entry.Pet, entry.Planet
			local rarity = Config.Rarities[pet.Rarity]
			local panel = UI.card(card, rarity.Color, UDim2.fromScale(1, 1), nil, "IndexCard")
			local glow = UI.stroke(panel, 4, rarity.Color, 0.1); glow.Name = "RarityGlow"
			local view = UI.viewport(panel, assets.Pets:FindFirstChild(entry.Species), UDim2.new(1, -20, 0.36, 0), UDim2.fromOffset(10, 6),
				{Silhouette = not entry.Known, Yaw = 0.6})
			view.ZIndex = 36
			local name = UI.text(panel, entry.Known and pet.Name or "???", UDim2.new(1, -20, 0, 32), UDim2.new(0, 10, 0.36, 4), 28)
			name.TextXAlignment = Enum.TextXAlignment.Center; name.TextWrapped = false; name.TextScaled = true; name.ZIndex = 36
			UI.new("UITextSizeConstraint", {MaxTextSize = 28}, name)
			local rarityLine = UI.text(panel, string.upper(pet.Rarity), UDim2.new(1, -20, 0, 22), UDim2.new(0, 10, 0.36, 36), 20, rarity.Color:Lerp(C.White, 0.35))
			rarityLine.TextXAlignment = Enum.TextXAlignment.Center; rarityLine.ZIndex = 36
			local class, studs = sizeClass(pet.Rarity)
			local facts = {
				"Chance  1 in " .. Config.Format(math.max(1, math.floor(entry.Odds + 0.5))),
				entry.Known and ("Earns  +" .. Config.Format(pet.Income) .. "/s") or "Earns  ???",
				"Size  " .. class .. "  (" .. math.floor(studs + 0.5) .. " studs)",
			}
			for i, line in ipairs(facts) do
				local t = UI.text(panel, line, UDim2.new(1, -20, 0, 20), UDim2.new(0, 10, 0.36, 58 + (i - 1) * 21), 17,
					i == 2 and Color3.fromRGB(120, 255, 90) or C.White)
				t.TextXAlignment = Enum.TextXAlignment.Center; t.ZIndex = 36
			end
			-- the eggs it hatches from (up to three), each with its chance
			local shown = math.min(3, #entry.Eggs)
			local hatchLine = UI.text(panel, "Hatches from:", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 1, -6 - shown * 50 - 20), 15, C.Soft)
			hatchLine.TextXAlignment = Enum.TextXAlignment.Center; hatchLine.ZIndex = 36
			for i = 1, shown do
				local src = entry.Eggs[i]
				local egg = src.Egg
				local eplanet = Config.Planets[egg.Planet or ""]
				local from = UI.new("Frame", {Name = "EggSource", BackgroundColor3 = C.White, Size = UDim2.new(1, -16, 0, 46),
					Position = UDim2.new(0, 8, 1, -4 - (shown - i + 1) * 50), ZIndex = 36}, panel)
				UI.round(from, 10)
				if eplanet then UI.gradient(from, eplanet.Color:Lerp(C.White, 0.1), eplanet.Color2:Lerp(C.Ink, 0.25), 0)
				else UI.gradient(from, Color3.fromRGB(255, 190, 220), Color3.fromRGB(150, 50, 120), 0) end
				UI.stroke(from, 2.5, C.Ink)
				local seen = src.Seen or entry.Known
				local eggView = UI.viewport(from, EggForge.Template(egg.Id), UDim2.fromOffset(42, 42), UDim2.fromOffset(3, 2), {Silhouette = not seen})
				eggView.ZIndex = 37
				local eggName = UI.text(from, seen and egg.Name or "??? Egg", UDim2.new(1, -110, 0, 22), UDim2.fromOffset(50, 3), 17)
				eggName.TextWrapped = false; eggName.TextScaled = true; eggName.ZIndex = 38
				UI.new("UITextSizeConstraint", {MaxTextSize = 17}, eggName)
				local where = eplanet and eplanet.Name or "Limited  ·  shop"
				local place = UI.text(from, where, UDim2.new(1, -110, 0, 16), UDim2.fromOffset(50, 25), 13, C.Soft)
				place.TextWrapped = false; place.TextScaled = true; place.ZIndex = 38
				UI.new("UITextSizeConstraint", {MaxTextSize = 13}, place)
				local pct = src.Chance * 100
				local chance = UI.text(from, (pct >= 10 and tostring(math.floor(pct + 0.5)) or string.format("%.1f", pct)) .. "%",
					UDim2.fromOffset(58, 40), UDim2.new(1, -62, 0, 3), 22, Color3.fromRGB(255, 230, 120))
				chance.TextXAlignment = Enum.TextXAlignment.Right; chance.TextWrapped = false; chance.ZIndex = 38
			end
		end
		local order, pick = 1, bySpecies[indexPick or ""]
		local function grid(entries, key)
			local g = UI.new("Frame", {Name = "Grid_" .. key, BackgroundTransparency = 1, Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = order, ZIndex = 34}, list)
			order += 1
			UI.new("UIGridLayout", {CellSize = UDim2.new(0.25, -8, 0, 104), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder}, g)
			for i, entry in ipairs(entries) do
				pick = pick or entry
				local rarity = Config.Rarities[entry.Pet.Rarity]
				local tile = UI.card(g, entry.Known and (entry.Limited and Color3.fromRGB(255, 150, 50) or rarity.Color) or C.Panel2, UDim2.new(), nil,
					"Index_" .. entry.Species)
				tile.LayoutOrder = i
				local view = UI.viewport(tile, assets.Pets:FindFirstChild(entry.Species), UDim2.new(1, -8, 0, 72), UDim2.fromOffset(4, 2),
					{Silhouette = not entry.Known, Spin = false, Yaw = 0.6})
				view.ZIndex = 36
				local name = entry.Known and entry.Pet.Name or "???"
				local label = UI.text(tile, name, UDim2.new(1, -8, 0, 28), UDim2.fromOffset(4, 74), 16)
				-- long meme names wrap onto two lines instead of shrinking to nothing on phones
				label.TextXAlignment = Enum.TextXAlignment.Center; label.TextWrapped = #name > 13; label.TextScaled = true; label.ZIndex = 36
				UI.new("UITextSizeConstraint", {MaxTextSize = 16}, label)
				local hit = UI.new("TextButton", {Name = "Pick", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 40}, tile)
				hit.Activated:Connect(function() UI.click(); showInfo(entry) end)
			end
		end
		for _, planet in ipairs(Config.PlanetOrder) do
			local entries = byPlanet[planet.Id] or {}
			local have = 0
			for _, e in ipairs(entries) do if e.Known then have += 1 end end
			planetBanner(list, planet, have, #entries, order); order += 1
			grid(entries, planet.Id)
		end
		local limited = byPlanet.Limited or {}
		if #limited > 0 then
			local egg = Config.LimitedEggs[1]
			local banner = UI.new("Frame", {Name = "Banner_Limited", BackgroundColor3 = C.White, Size = UDim2.new(1, -10, 0, 58), LayoutOrder = order, ZIndex = 34}, list)
			order += 1
			UI.round(banner, 14)
			UI.gradient(banner, Color3.fromRGB(255, 170, 60), Color3.fromRGB(80, 30, 120), 0)
			UI.stroke(banner, 3, C.Ink)
			if egg then UI.viewport(banner, EggForge.Template(egg.Id), UDim2.fromOffset(52, 52), UDim2.fromOffset(6, 3), {Yaw = 0.5}).ZIndex = 35 end
			local t = UI.text(banner, "LIMITED  ·  " .. (egg and egg.Name or ""), UDim2.new(1, -170, 0, 30), UDim2.fromOffset(62, 4), 24)
			t.TextWrapped = false; t.ZIndex = 36
			local w = UI.text(banner, "Only in the shop  ·  1000 in the whole game", UDim2.new(1, -170, 0, 20), UDim2.fromOffset(62, 33), 15, C.White)
			w.TextWrapped = false; w.ZIndex = 36
			local have = 0
			for _, e in ipairs(limited) do if e.Known then have += 1 end end
			local tally = UI.text(banner, have .. "/" .. #limited, UDim2.fromOffset(92, 40), UDim2.new(1, -100, 0, 9), 28, C.White)
			tally.TextXAlignment = Enum.TextXAlignment.Right; tally.ZIndex = 36
			grid(limited, "Limited")
		end
		showInfo(pick)
	end

	-- ---------------------------------------------------------------- the limited offer (shop banner)
	-- v28 Halloween: a big pumpkin-orange card - the Haunted Pumpkin Egg turning in front of a sunburst, bats and
	-- autumn leaves flying past, its three SECRET pets (black silhouettes with "???" until you have hatched one)
	-- with their chances, how many are left of the 1000 (live, from every server) and the price.
	local SAKURA, SAKURA_DEEP = Color3.fromRGB(255, 140, 40), Color3.fromRGB(110, 40, 170)
	function Menus.LimitedBanner(parent, product, order)
		local egg = Config.Eggs[product.EggId]
		if not egg then return end
		local card = UI.new("Frame", {Name = "Limited_" .. product.Key, BackgroundColor3 = C.White, Size = UDim2.new(1, -8, 0, 262),
			LayoutOrder = order, ClipsDescendants = true, ZIndex = 34}, parent)
		UI.round(card, 18)
		UI.new("UIGradient", {Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 90)),
			ColorSequenceKeypoint.new(0.5, SAKURA), ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 20, 90))}), Rotation = 25}, card)
		UI.stroke(card, 4, C.Ink)
		-- bats and falling leaves behind everything
		local petals = {}
		for i = 1, 14 do
			local bat = i % 3 == 0
			local petal = UI.new("Frame", {Name = bat and "Bat" or "Leaf", BackgroundColor3 = bat and Color3.fromRGB(30, 16, 40)
				or (i % 2 == 0 and Color3.fromRGB(255, 120, 30) or Color3.fromRGB(200, 70, 30)),
				BackgroundTransparency = 0.1, Size = bat and UDim2.fromOffset(22, 8) or UDim2.fromOffset(10 + i % 4 * 3, 7 + i % 3 * 2), ZIndex = 35}, card)
			UI.round(petal, UDim.new(0.5, 0))
			if bat then
				for side = -1, 1, 2 do
					local wing = UI.new("Frame", {BackgroundColor3 = petal.BackgroundColor3, BorderSizePixel = 0, Size = UDim2.fromOffset(12, 6),
						Position = UDim2.new(0.5, side * 10 - 6, 0, -3), Rotation = side * 25, ZIndex = 35}, petal)
					UI.round(wing, 3)
				end
			end
			table.insert(petals, {Frame = petal, X = math.random(), Speed = 0.12 + math.random() * 0.16, Phase = math.random() * 6, Y = math.random()})
		end
		local burst = UI.sunburst(card, UDim2.fromOffset(330, 330), Color3.fromRGB(255, 240, 250), 0.35)
		burst.Position = UDim2.fromOffset(-40, -40); burst.ZIndex = 36
		local eggView = UI.viewport(card, EggForge.Template(product.EggId), UDim2.fromOffset(230, 230), UDim2.fromOffset(12, 16), {Yaw = 0.5})
		eggView.ZIndex = 37
		local ribbon = UI.pill(card, "LIMITED", C.Red, UDim2.fromOffset(120, 32), UDim2.fromOffset(14, 12), 20)
		ribbon.ZIndex = 40; ribbon.Rotation = -8
		for _, d in ipairs(ribbon:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex = 41 end end
		local name = UI.text(card, string.upper(egg.Name), UDim2.fromOffset(420, 46), UDim2.fromOffset(258, 10), 44)
		name.TextWrapped = false; name.ZIndex = 40
		UI.new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(255, 250, 220), Color3.fromRGB(255, 170, 60)), Rotation = 90}, name)
		local line = UI.text(card, egg.Secret and "Hatches one of three SECRET pets:" or "Hatches one of three pets:", UDim2.fromOffset(420, 22),
			UDim2.fromOffset(260, 56), 17, C.White)
		line.ZIndex = 40
		local total = 0
		for _, drop in ipairs(egg.Drops or {}) do total += drop[2] end
		for i, drop in ipairs(egg.Drops or {}) do
			local pet = Config.Pets[drop[1]]
			local holder = UI.new("Frame", {BackgroundColor3 = C.Ink, BackgroundTransparency = 0.55, Size = UDim2.fromOffset(108, 118),
				Position = UDim2.fromOffset(258 + (i - 1) * 114, 82), ZIndex = 38}, card)
			UI.round(holder, 12)
			UI.stroke(holder, 2, SAKURA_DEEP, 0.2)
			local known = not (pet and pet.Secret) or (store.state.DiscoveredPets and store.state.DiscoveredPets[drop[1]] == true)
			local view = UI.viewport(holder, assets.Pets:FindFirstChild(drop[1]), UDim2.fromOffset(98, 74), UDim2.fromOffset(5, 2),
				{Yaw = 0.6, Silhouette = not known})
			view.ZIndex = 39
			if not known then
				local q = UI.text(holder, "?", UDim2.fromOffset(98, 74), UDim2.fromOffset(5, 2), 54, Color3.fromRGB(255, 200, 80))
				q.TextXAlignment = Enum.TextXAlignment.Center; q.ZIndex = 40
			end
			local n = UI.text(holder, known and (pet and pet.Name or drop[1]) or "???", UDim2.new(1, -8, 0, 20), UDim2.fromOffset(4, 74), 15)
			n.TextXAlignment = Enum.TextXAlignment.Center; n.TextWrapped = false; n.TextScaled = true; n.ZIndex = 40
			UI.new("UITextSizeConstraint", {MaxTextSize = 15}, n)
			local chance = UI.text(holder, math.floor(drop[2] / math.max(1, total) * 100 + 0.5) .. "%", UDim2.new(1, -8, 0, 20), UDim2.fromOffset(4, 94), 17,
				Color3.fromRGB(255, 230, 120))
			chance.TextXAlignment = Enum.TextXAlignment.Center; chance.ZIndex = 40
		end
		-- how many are left (of all ever sold, in every server)
		local stockText = UI.text(card, "", UDim2.fromOffset(300, 24), UDim2.fromOffset(260, 206), 18, C.White)
		stockText.ZIndex = 40; stockText.TextWrapped = false
		local _, setStock = UI.bar(card, UDim2.fromOffset(300, 16), UDim2.fromOffset(260, 234), SAKURA_DEEP)
		local configured = (product.Id or 0) > 0
		-- the price button right of the three pets (never over them), a Robux icon before the price
		local button = UI.button(card, configured and tostring(product.Price or 999) or "SOON", C.Green, UDim2.new(1, -620, 0, 64),
			UDim2.fromOffset(608, 108), function()
				if configured and store.send then store.send("BuyLimited", product.Key) end
			end, {TextSize = 30, Icon = configured and "Robux" or nil, Name = "BuyLimited"})
		button.ZIndex = 42
		local function refresh()
			local stock = workspace:GetAttribute("PFELimitedStock_" .. product.Key) or product.Stock or 1000
			local sold = workspace:GetAttribute("PFELimitedSold_" .. product.Key) or 0
			local left = math.max(0, stock - sold)
			stockText.Text = left > 0 and (tostring(left) .. " / " .. tostring(stock) .. " left") or "SOLD OUT"
			setStock(left / math.max(1, stock))
			if left <= 0 then UI.disable(button, true) elseif not configured then UI.disable(button, true) end
		end
		refresh()
		local a = workspace:GetAttributeChangedSignal("PFELimitedSold_" .. product.Key):Connect(refresh)
		local spin = 0
		local step = RunService.RenderStepped:Connect(function(dt)
			spin += dt
			burst.Rotation = spin * 12
			for _, p in ipairs(petals) do
				p.Y += p.Speed * dt
				if p.Y > 1.1 then p.Y = -0.1; p.X = math.random() end
				p.Frame.Position = UDim2.fromScale(p.X + math.sin(spin * 1.3 + p.Phase) * 0.03, p.Y)
				p.Frame.Rotation = (spin * 60 + p.Phase * 40) % 360
			end
		end)
		card.Destroying:Connect(function() a:Disconnect(); step:Disconnect() end)
		return card
	end

	-- ---------------------------------------------------------------- fusion
	-- Three eggs from the backpack into the three slots, the odds of what comes out, FUSE.
	-- (v38) built once per opening and never torn down on a tap: identical eggs share one card with a count,
	-- a pick only redraws the three slots and the picked card; the 3D previews are made a few per frame.
	local fuseBuild = 0
	function renderers.Fusion(state)
		fuseBuild += 1
		local build = fuseBuild
		UI.list(scroll, 12)
		local eggs, byId = {}, {}
		for _, egg in ipairs(state.Eggs or {}) do
			if Config.Eggs[egg.EggId] then table.insert(eggs, egg); byId[egg.Id] = egg end
		end
		for i = #fusePick, 1, -1 do if not byId[fusePick[i]] then table.remove(fusePick, i) end end
		-- the same egg (kind, mutation, size) in one stack
		local stacks, stackOf = {}, {}
		for _, egg in ipairs(eggs) do
			local key = egg.EggId .. "|" .. (egg.Mutation or "Normal") .. "|" .. Config.SizeName(egg.Scale)
			local stack = stackOf[key]
			if not stack then
				stack = {Key = key, Egg = egg, Info = Config.Eggs[egg.EggId], Ids = {}}
				stackOf[key] = stack
				table.insert(stacks, stack)
			end
			table.insert(stack.Ids, egg.Id)
		end
		local function orderOf(stack) local r = Config.Rarities[stack.Info.Rarity]; return r and r.Order or 0 end
		table.sort(stacks, function(x, y)
			if orderOf(x) ~= orderOf(y) then return orderOf(x) > orderOf(y) end
			return x.Key < y.Key
		end)
		local picked = {}
		local function repick() table.clear(picked); for _, id in ipairs(fusePick) do picked[id] = true end end
		repick()
		local top = UI.card(scroll, C.Pink, UDim2.new(1, -8, 0, 230), nil, "FusionSlots")
		top.LayoutOrder = 1
		local slots = {}
		for i = 1, Config.FusionCost do
			local slot = UI.new("TextButton", {Name = "Slot" .. i, Text = "", AutoButtonColor = false, BackgroundColor3 = C.Ink, BackgroundTransparency = 0.35,
				Size = UDim2.fromOffset(130, 130), Position = UDim2.fromOffset(18 + (i - 1) * 168, 18), ZIndex = 36}, top)
			UI.round(slot, 16)
			local stroke = UI.stroke(slot, 4, C.Panel2, 0)
			local content = UI.new("Frame", {Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 36}, slot)
			slots[i] = {Button = slot, Stroke = stroke, Content = content, Id = false}
			if i < Config.FusionCost then
				local sign = UI.text(top, "+", UDim2.fromOffset(38, 130), UDim2.fromOffset(18 + (i - 1) * 168 + 130, 18), 44)
				sign.TextXAlignment = Enum.TextXAlignment.Center; sign.ZIndex = 37
			end
		end
		local eq = UI.text(top, "=", UDim2.fromOffset(40, 130), UDim2.fromOffset(18 + 3 * 168 - 38, 18), 48)
		eq.TextXAlignment = Enum.TextXAlignment.Center; eq.ZIndex = 37
		local result = UI.new("Frame", {Name = "Result", BackgroundColor3 = C.Ink, BackgroundTransparency = 0.35, Size = UDim2.new(1, -18 - 3 * 168 - 14, 0, 130),
			Position = UDim2.fromOffset(18 + 3 * 168 + 4, 18), ZIndex = 36}, top)
		UI.round(result, 16)
		UI.stroke(result, 4, C.White, 0.3)
		local odds = UI.text(result, "", UDim2.new(1, -12, 1, -8), UDim2.fromOffset(6, 4), 18)
		odds.TextXAlignment = Enum.TextXAlignment.Center; odds.ZIndex = 37
		local fuse = UI.button(top, "FUSE!", C.Muted, UDim2.new(1, -36, 0, 56), UDim2.new(0, 18, 1, -70), function()
			if #fusePick ~= Config.FusionCost or not store.send then return end
			store.send("Fuse", table.clone(fusePick))
			fusePick = {}
			Menus.Close()
		end, {TextSize = 30, Name = "FuseButton"})
		local cards = {}
		local refreshCards
		-- the three slots, the odds and the button (a tap redraws only these)
		local function drawSlots()
			local rarities = {}
			for i, slot in ipairs(slots) do
				local id = fusePick[i]
				local egg = id and byId[id]
				local info = egg and Config.Eggs[egg.EggId]
				if (slot.Id or false) ~= (id or false) then
					slot.Id = id or false
					for _, c in ipairs(slot.Content:GetChildren()) do c:Destroy() end
					if egg then
						UI.viewport(slot.Content, EggForge.Template(egg.EggId), UDim2.new(1, -10, 1, -10), UDim2.fromOffset(5, 5), {Yaw = 0.5}).ZIndex = 37
					else
						local plus = UI.text(slot.Content, "+", UDim2.fromScale(1, 1), nil, 64, C.Soft)
						plus.TextXAlignment = Enum.TextXAlignment.Center; plus.ZIndex = 37
					end
				end
				slot.Stroke.Color = info and Config.Rarities[info.Rarity].Color or C.Panel2
				if info then table.insert(rarities, info.Rarity) end
			end
			local lines = {}
			if #rarities == Config.FusionCost then
				for _, row in ipairs(Config.FusionOdds(rarities)) do
					table.insert(lines, '<font color="#' .. Config.Rarities[row.Rarity].Color:ToHex() .. '">' .. string.upper(row.Rarity) .. "</font>  "
						.. math.floor(row.Chance * 100 + 0.5) .. "%")
				end
			else
				table.insert(lines, "Pick " .. (Config.FusionCost - #rarities) .. " more egg" .. (Config.FusionCost - #rarities == 1 and "" or "s"))
			end
			odds.Text = "NEW EGG\n" .. table.concat(lines, "\n")
			local ready = #rarities == Config.FusionCost
			UI.setButtonColor(fuse, ready and C.Pink or C.Muted)
			UI.disable(fuse, not ready)
		end
		local function changed() repick(); drawSlots(); refreshCards() end
		for i, slot in ipairs(slots) do
			slot.Button.Activated:Connect(function()
				if not fusePick[i] then return end
				UI.click(); table.remove(fusePick, i); changed()
			end)
		end
		-- the backpack: one card per stack
		section(#eggs == 0 and "No eggs in your backpack - find some on the planets!" or "Your eggs (tap to add)", 2, C.Soft)
		local g = grid(3, 150, columns + 2)
		local queue = {}
		for i, stack in ipairs(stacks) do
			if i > 120 then break end
			local info = stack.Info
			local rarity = Config.Rarities[info.Rarity]
			local card = UI.card(g, rarity.Color, UDim2.new(), nil, "FuseEgg_" .. stack.Ids[1])
			card.LayoutOrder = i
			local holder = UI.new("Frame", {Name = "Preview", BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, 88), Position = UDim2.fromOffset(6, 6),
				ZIndex = 36}, card)
			table.insert(queue, {Holder = holder, EggId = stack.Egg.EggId})
			local n = UI.text(card, Config.EggDisplayName(stack.Egg), UDim2.new(1, -10, 0, 22), UDim2.fromOffset(5, 96), 15)
			n.TextXAlignment = Enum.TextXAlignment.Center; n.TextWrapped = false; n.TextScaled = true; n.ZIndex = 36
			UI.new("UITextSizeConstraint", {MaxTextSize = 15}, n)
			local r = UI.text(card, info.Rarity, UDim2.new(1, -10, 0, 18), UDim2.fromOffset(5, 120), 14, rarity.Color:Lerp(C.White, 0.4))
			r.TextXAlignment = Enum.TextXAlignment.Center; r.ZIndex = 36
			local count = UI.pill(card, "x" .. #stack.Ids, C.Ink, UDim2.fromOffset(54, 26), UDim2.new(1, -60, 0, 6), 18)
			count.Name = "Count"; count.ZIndex = 38
			for _, d in ipairs(count:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex = 39 end end
			local shade = UI.new("Frame", {Name = "Shade", BackgroundColor3 = C.Ink, BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Visible = false,
				ZIndex = 39}, card)
			UI.round(shade, 16)
			local hit = UI.new("TextButton", {Name = "Pick", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 40}, card)
			cards[stack] = {Card = card, Count = count, Shade = shade}
			hit.Activated:Connect(function()
				UI.click()
				if #fusePick >= Config.FusionCost then return end
				for _, id in ipairs(stack.Ids) do
					if not picked[id] then table.insert(fusePick, id); break end
				end
				changed()
			end)
		end
		if #stacks > 120 then section("+" .. (#stacks - 120) .. " more kinds of eggs", 4, C.Soft) end
		function refreshCards()
			for stack, c in pairs(cards) do
				local left = 0
				for _, id in ipairs(stack.Ids) do if not picked[id] then left += 1 end end
				local label = c.Count:FindFirstChildWhichIsA("TextLabel", true) or c.Count
				pcall(function() label.Text = "x" .. left end)
				c.Shade.Visible = left == 0
			end
		end
		drawSlots(); refreshCards()
		-- the 3D previews: a few per frame, not all at once
		task.spawn(function()
			for k, item in ipairs(queue) do
				if build ~= fuseBuild or not item.Holder.Parent then return end
				UI.viewport(item.Holder, EggForge.Template(item.EggId), UDim2.fromScale(1, 1), nil, {Spin = false, Yaw = 0.5}).ZIndex = 36
				if k % 3 == 0 then RunService.Heartbeat:Wait() end
			end
		end)
	end

	-- ---------------------------------------------------------------- codes & the Free reward
	local okAES, AvatarEditorService = pcall(function() return game:GetService("AvatarEditorService") end)
	if not okAES then AvatarEditorService = nil end
	local codeResult, freeResult = nil, nil
	local function centerCard(color, height, name)
		local holder = UI.new("Frame", {Name = name .. "Holder", BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, height), LayoutOrder = 1}, scroll)
		local card = UI.card(holder, color, UDim2.new(0, 560, 1, 0), UDim2.new(0.5, -280, 0, 0), name)
		return card
	end
	function renderers.Codes(state)
		UI.list(scroll, 14)
		local card = centerCard(C.Cyan, 330, "CodesCard")
		UI.sunburst(card, UDim2.fromOffset(260, 260), C.White, 0.7).Position = UDim2.fromOffset(90, 80)
		UI.icon(card, "Ticket", UDim2.fromOffset(120, 120), UDim2.fromOffset(30, 20), {ZIndex = 6})
		local head = UI.text(card, "ENTER A CODE", UDim2.fromOffset(360, 44), UDim2.fromOffset(170, 26), 38)
		head.TextWrapped = false
		local sub = UI.text(card, "New codes come with updates and likes!", UDim2.fromOffset(360, 26), UDim2.fromOffset(170, 72), 18, C.White)
		sub.TextWrapped = false
		local boxFrame = UI.new("Frame", {BackgroundColor3 = C.Ink, BackgroundTransparency = 0.25, Size = UDim2.new(1, -60, 0, 64),
			Position = UDim2.fromOffset(30, 160), ZIndex = 6}, card)
		UI.round(boxFrame, 14); UI.stroke(boxFrame, 3, C.White, 0.4)
		local box = UI.new("TextBox", {Name = "CodeBox", BackgroundTransparency = 1, Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(12, 0),
			Text = "", PlaceholderText = "Type the code here...", PlaceholderColor3 = C.Soft, TextColor3 = C.White, FontFace = UI.FontHeavy,
			TextSize = 30, ClearTextOnFocus = false, ZIndex = 7}, boxFrame)
		local result = UI.text(card, codeResult and codeResult.Text or "", UDim2.new(1, -40, 0, 28), UDim2.new(0, 20, 1, -106), 20,
			codeResult and (codeResult.Ok and Color3.fromRGB(120, 255, 90) or C.Red) or C.White)
		result.Name = "CodeResult"; result.TextXAlignment = Enum.TextXAlignment.Center
		UI.button(card, "REDEEM", C.Green, UDim2.fromOffset(260, 58), UDim2.new(0.5, -130, 1, -72), function()
			if box.Text ~= "" and store.send then store.send("RedeemCode", box.Text) end
		end, {TextSize = 30, Name = "RedeemButton"})
	end
	local function favorited()
		local ok, value = pcall(function() return AvatarEditorService:GetFavorite(game.PlaceId, Enum.AvatarItemType.Asset) end)
		if not AvatarEditorService then ok = false end
		if ok then return value == true end
		return game.PlaceId == 0 -- (an unpublished test place can't be favourited: count it as done there)
	end
	function renderers.Free(state)
		UI.list(scroll, 14)
		local stage = state.FreeStage or 0
		local card = centerCard(C.Gold, 380, "FreeCard")
		UI.sunburst(card, UDim2.fromOffset(280, 280), C.White, 0.65).Position = UDim2.fromOffset(100, 100)
		UI.icon(card, "Gift", UDim2.fromOffset(130, 130), UDim2.fromOffset(34, 30), {ZIndex = 6})
		local head = UI.text(card, stage >= 2 and "VIP CLAIMED!" or "FREE VIP!", UDim2.fromOffset(340, 50), UDim2.fromOffset(190, 24), 44)
		head.TextWrapped = false
		local steps = {"1.  Like the game  👍", "2.  Press CLAIM and add it to favourites  ⭐", "3.  Rejoin the game - VIP is yours!"}
		for i, line in ipairs(steps) do
			local t = UI.text(card, line, UDim2.fromOffset(360, 28), UDim2.fromOffset(180, 78 + (i - 1) * 30), 19, C.White)
			t.TextWrapped = false; t.TextScaled = true
			UI.new("UITextSizeConstraint", {MaxTextSize = 19}, t)
		end
		local text = freeResult and freeResult.Text
			or (stage == 1 and "Almost done! Leave the game and join again - your VIP will be waiting.")
			or (stage >= 2 and "Thank you for the support!") or "VIP for 24 hours: +10% coins, +10% air, a daily gift."
		local result = UI.text(card, text, UDim2.new(1, -40, 0, 52), UDim2.new(0, 20, 1, -140), 19, C.White)
		result.Name = "FreeResult"; result.TextXAlignment = Enum.TextXAlignment.Center
		-- one button: CLAIM (not in the favourites yet? Roblox's own "add to favourites" window opens first)
		local claim = UI.button(card, stage >= 2 and "CLAIMED" or stage == 1 and "CHECK" or "CLAIM", C.Green, UDim2.fromOffset(280, 62), UDim2.new(0.5, -140, 1, -80), function()
			task.spawn(function()
				local fav = favorited()
				-- the favourites window only on the first press (stage 0); after that only the rejoin counts
				if stage == 0 and not fav and AvatarEditorService then
					local done = false
					local connection
					pcall(function() connection = AvatarEditorService.PromptSetFavoriteCompleted:Connect(function() done = true end) end)
					pcall(function() AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true) end)
					local started = os.clock()
					while not done and os.clock() - started < 60 do task.wait(0.2) end
					if connection then connection:Disconnect() end
					fav = favorited()
				end
				if store.send then store.send("FreeClaim", {Favorited = fav}) end
			end)
		end, {TextSize = 30, Name = "ClaimButton"})
		if stage >= 2 then UI.disable(claim, true) end
	end
	-- ---------------------------------------------------------------- (v38) the daily calendar
	-- Seven days of gifts (Config.Daily): today's card glows with a CLAIM button, the claimed ones get a tick, tomorrow's
	-- teases what is coming; the seventh is the big one. A claim bursts the reward out over the menu.
	local GOLD = Color3.fromRGB(255, 200, 60)
	local dailyBurst = nil
	local function rewardVisual(parent, day, entry, size, pos, z)
		local holder = UI.new("Frame", {Name = "Reward", BackgroundTransparency = 1, Size = size, Position = pos, ZIndex = z}, parent)
		local glow = entry.Kind == "Egg" and Config.Rarities[entry.Rarity].Color or GOLD
		local burst = UI.sunburst(holder, UDim2.fromScale(1.35, 1.35), glow, 0.55)
		burst.AnchorPoint = Vector2.new(0.5, 0.5); burst.Position = UDim2.fromScale(0.5, 0.5); burst.ZIndex = z
		if entry.Kind == "Egg" then
			local view = UI.viewport(holder, EggForge.Template(Config.DailyEggId(day)), UDim2.fromScale(1, 1), nil, {Yaw = 0.4})
			view.ZIndex = z + 1
		else
			UI.icon(holder, entry.Icon or "Gift", UDim2.fromScale(0.86, 0.86), UDim2.fromScale(0.07, 0.07), {ZIndex = z + 1})
		end
		return holder
	end
	local function clock(seconds)
		seconds = math.max(0, math.floor(seconds))
		return string.format("%02d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
	end
	function renderers.Daily(state)
		UI.list(scroll, 14)
		local daily = state.Daily or {Day = 1, Tomorrow = 2, Claimable = false, Streak = 0, ResetAt = os.time() + 3600}
		local days = Config.Daily.Days
		-- the header: the title in gold, the streak, the countdown
		local head = UI.card(scroll, Color3.fromRGB(255, 120, 200), UDim2.new(1, -8, 0, 118), nil, "DailyHeader")
		head.LayoutOrder = 1
		local rays = UI.sunburst(head, UDim2.fromOffset(240, 240), C.White, 0.72)
		rays.AnchorPoint = Vector2.new(0.5, 0.5); rays.Position = UDim2.fromOffset(70, 59); rays.ZIndex = 4
		UI.icon(head, "GiftPink", UDim2.fromOffset(96, 96), UDim2.fromOffset(22, 11), {ZIndex = 6})
		local title = UI.text(head, "DAILY REWARDS", UDim2.new(1, -150, 0, 50), UDim2.fromOffset(136, 10), 46)
		title.TextWrapped = false; title.ZIndex = 6
		UI.new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 252, 210), Color3.fromRGB(255, 186, 40))}, title)
		local sub = UI.text(head, daily.Streak > 0 and ("Streak: " .. daily.Streak .. " day" .. (daily.Streak == 1 and "" or "s") .. "  -  don't break it!")
			or "Come back every day - the gifts get bigger!", UDim2.new(1, -150, 0, 26), UDim2.fromOffset(138, 58), 20, C.White)
		sub.TextWrapped = false; sub.ZIndex = 6
		local timer = UI.text(head, "", UDim2.new(1, -150, 0, 24), UDim2.fromOffset(138, 84), 19, Color3.fromRGB(255, 230, 140))
		timer.Name = "DailyTimer"; timer.TextWrapped = false; timer.ZIndex = 6
		local function tick()
			local left = (daily.ResetAt or 0) - os.time()
			timer.Text = daily.Claimable and "Today's gift is waiting - claim it!" or ("Next gift in " .. clock(left))
		end
		tick()
		task.spawn(function()
			while timer.Parent do task.wait(1); if timer.Parent then tick() end end
		end)
		-- the seven days: two rows, the seventh twice as wide
		local board = UI.new("Frame", {Name = "DailyBoard", BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 2 * 232), LayoutOrder = 2, ZIndex = 33}, scroll)
		for d, entry in ipairs(days) do
			local row, col = d <= 4 and 0 or 1, d <= 4 and d - 1 or d - 5
			local wide = d == #days
			local claimed = (daily.Claimable and daily.Day > 1 and d < daily.Day) or (not daily.Claimable and d <= daily.Day)
			local today = daily.Claimable and d == daily.Day
			local tomorrow = not daily.Claimable and d == daily.Tomorrow
			local color = wide and GOLD or (entry.Kind == "Egg" and Config.Rarities[entry.Rarity].Color or Color3.fromRGB(90, 200, 255))
			local card = UI.card(board, claimed and C.Muted or color, UDim2.new(wide and 0.5 or 0.25, -12, 0, 216),
				UDim2.new(col * 0.25, 6, 0, row * 232), "Day" .. d)
			card.ZIndex = 34
			local pill = UI.pill(card, "DAY " .. d, today and C.Green or (wide and Color3.fromRGB(255, 150, 40) or C.Ink), UDim2.fromOffset(86, 28),
				UDim2.fromOffset(10, 8), 18)
			pill.ZIndex = 40
			for _, x in ipairs(pill:GetDescendants()) do if x:IsA("GuiObject") then x.ZIndex = 41 end end
			local vis = rewardVisual(card, d, entry, wide and UDim2.fromOffset(150, 150) or UDim2.fromOffset(104, 104),
				wide and UDim2.new(0, 20, 0, 40) or UDim2.new(0.5, -52, 0, 34), 36)
			vis.Name = "Reward"
			local textX = wide and 186 or 8
			local textW = wide and -196 or -16
			local name = UI.text(card, entry.Name, UDim2.new(1, textW, 0, 26), UDim2.new(0, textX, 0, wide and 52 or 140), wide and 30 or 19)
			name.TextWrapped = false; name.TextScaled = true; name.ZIndex = 37
			UI.new("UITextSizeConstraint", {MaxTextSize = wide and 30 or 19}, name)
			if not wide then name.TextXAlignment = Enum.TextXAlignment.Center end
			local hintText = entry.Hint or ""
			local coins = Config.DailyCoins(entry, state.Income)
			if coins > 0 then hintText = "+" .. Config.Format(coins) .. " coins" .. (entry.Kind ~= "Coins" and ("  &  " .. hintText) or "") end
			local hint = UI.text(card, hintText, UDim2.new(1, textW, 0, wide and 52 or 36), UDim2.new(0, textX, 0, wide and 86 or 166), wide and 20 or 14,
				Color3.fromRGB(235, 235, 245))
			hint.ZIndex = 37
			if not wide then hint.TextXAlignment = Enum.TextXAlignment.Center end
			if claimed then
				local shade = UI.new("Frame", {Name = "Claimed", BackgroundColor3 = C.Ink, BackgroundTransparency = 0.4, Size = UDim2.fromScale(1, 1), ZIndex = 42}, card)
				UI.round(shade, 16)
				UI.icon(shade, "Check", UDim2.fromOffset(78, 78), UDim2.new(0.5, -39, 0.5, -46), {ZIndex = 43})
				local done = UI.text(shade, "CLAIMED", UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0.5, 34), 20, C.Green)
				done.TextXAlignment = Enum.TextXAlignment.Center; done.ZIndex = 43
			elseif today then
				-- today's: a pulsing gold rim and its own CLAIM button
				local rim = UI.stroke(card, 5, GOLD, 0)
				task.spawn(function()
					local t0 = os.clock()
					while rim.Parent do
						local k = (math.sin((os.clock() - t0) * 5) + 1) / 2
						rim.Transparency = k * 0.6
						rim.Thickness = 4 + k * 3
						RunService.Heartbeat:Wait()
					end
				end)
				local claim = UI.button(card, "CLAIM!", C.Green, wide and UDim2.fromOffset(220, 50) or UDim2.new(1, -24, 0, 40),
					wide and UDim2.new(1, -236, 1, -62) or UDim2.new(0, 12, 1, -48), function()
						if store.send then store.send("ClaimDaily") end
					end, {TextSize = wide and 28 or 22, Name = "ClaimDaily"})
				claim.ZIndex = 44
			elseif tomorrow then
				local soon = UI.pill(card, d == 2 and "TOMORROW: 2X!" or "TOMORROW", Color3.fromRGB(255, 120, 200), UDim2.new(1, -24, 0, 30),
					UDim2.new(0, 12, 1, -40), 16)
				soon.ZIndex = 44
				for _, x in ipairs(soon:GetDescendants()) do if x:IsA("GuiObject") then x.ZIndex = 45 end end
			else
				UI.icon(card, "Lock", UDim2.fromOffset(30, 30), UDim2.new(1, -40, 0, 8), {ZIndex = 44, ImageTransparency = 0.2})
			end
		end
		-- the big button at the bottom too
		local foot = UI.new("Frame", {Name = "DailyFoot", BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 70), LayoutOrder = 3, ZIndex = 33}, scroll)
		local big = UI.button(foot, daily.Claimable and ("CLAIM DAY " .. daily.Day .. "!") or "COME BACK TOMORROW", daily.Claimable and C.Green or C.Muted,
			UDim2.fromOffset(380, 60), UDim2.new(0.5, -190, 0, 4), function()
				if daily.Claimable and store.send then store.send("ClaimDaily") end
			end, {TextSize = 28, Name = "ClaimDailyBig"})
		if not daily.Claimable then UI.disable(big, true) end
	end
	-- the claim: the reward bursts out over the menu
	local function celebrate(payload)
		local day = payload.Day or 1
		local entry = Config.Daily.Days[day]
		if not entry then return end
		local holder = UI.new("Frame", {Name = "DailyBurst", BackgroundColor3 = C.Ink, BackgroundTransparency = 0.25, Size = UDim2.fromScale(1, 1), ZIndex = 80},
			modal)
		UI.round(holder, 20)
		local rays = UI.sunburst(holder, UDim2.fromOffset(520, 520), day == #Config.Daily.Days and GOLD or C.White, 0.5)
		rays.AnchorPoint = Vector2.new(0.5, 0.5); rays.Position = UDim2.fromScale(0.5, 0.45); rays.ZIndex = 81
		local vis = rewardVisual(holder, day, entry, UDim2.fromOffset(220, 220), UDim2.new(0.5, -110, 0.45, -110), 82)
		local scale = UI.new("UIScale", {Scale = 0.2}, vis)
		UI.tween(scale, {Scale = 1}, 0.55, Enum.EasingStyle.Back)
		local text = "DAY " .. day .. ": " .. string.upper(entry.Name) .. "!"
		local big = UI.text(holder, text, UDim2.new(1, -40, 0, 52), UDim2.new(0, 20, 0.45, 120), 42)
		big.TextXAlignment = Enum.TextXAlignment.Center; big.TextWrapped = false; big.TextScaled = true; big.ZIndex = 84
		UI.new("UITextSizeConstraint", {MaxTextSize = 42}, big)
		UI.new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 252, 210), Color3.fromRGB(255, 186, 40))}, big)
		local line = entry.Kind == "Egg" and "In your backpack - plant it at your base!" or (payload.Coins and ("+" .. Config.Format(payload.Coins) .. " coins") or entry.Hint)
		local small = UI.text(holder, line or "", UDim2.new(1, -40, 0, 30), UDim2.new(0, 20, 0.45, 172), 22, C.White)
		small.TextXAlignment = Enum.TextXAlignment.Center; small.ZIndex = 84
		pcall(function()
			local s = Config.Sounds
			if store.Popups then store.Popups.Play(day == #Config.Daily.Days and s.Legendary or s.Reward, 0.7, 1) end
		end)
		local tap = UI.new("TextButton", {Name = "Close", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 90}, holder)
		local gone = false
		local function close()
			if gone then return end
			gone = true
			UI.tween(holder, {BackgroundTransparency = 1}, 0.25)
			task.delay(0.25, function() holder:Destroy() end)
		end
		tap.Activated:Connect(close)
		task.delay(3.2, close)
		dailyBurst = holder
	end
	Menus.OnEffect = function(kind, payload)
		if kind == "DailyClaimed" then
			if type(payload) == "table" then
				if active ~= "Daily" then Menus.Open("Daily") end
				celebrate(payload)
			end
			return
		end
		if kind == "CodeResult" then
			codeResult = payload
			UI.click()
			if active == "Codes" then Menus.Render(true) end
		elseif kind == "FreeResult" then
			freeResult = payload
			if active == "Free" then Menus.Render(true) end
		end
	end
	-- (v38) today's gift waiting: the calendar opens by itself once a visit, when nothing else is on screen
	local dailyShown = false
	store.on(function(state)
		if dailyShown or not (state.Daily and state.Daily.Claimable) then return end
		dailyShown = true
		task.spawn(function()
			local deadline = os.clock() + 900
			repeat task.wait(1) until os.clock() > deadline or (player:GetAttribute("IntroActive") == false and not player:GetAttribute("PFECutscene")
				and not store.menuOpen() and not store.flying() and not store.state.Busy)
			if os.clock() > deadline then return end
			task.wait(1.5)
			if store.state.Daily and store.state.Daily.Claimable and not store.menuOpen() and not player:GetAttribute("PFECutscene") then
				Menus.Open("Daily")
			end
		end)
	end)
	-- back in the game with the Free reward half done: check the favourite again (the second step)
	local rechecked = false
	store.on(function(state)
		if rechecked or (state.FreeStage or 0) ~= 1 then return end
		rechecked = true
		task.spawn(function() if store.send then store.send("FreeCheck", {Favorited = favorited()}) end end)
	end)

	local function upgradeCard(order, color, heading, sub)
		local card = UI.card(scroll, color, UDim2.new(1, -8, 0, 176), nil, heading:gsub("%s", "") .. "Card")
		card.LayoutOrder = order
		local h = UI.text(card, heading, UDim2.new(1, -200, 0, 38), UDim2.fromOffset(176, 12), 32)
		h.TextWrapped = false
		local s = UI.text(card, sub, UDim2.new(1, -200, 0, 26), UDim2.fromOffset(176, 50), 19, C.White)
		s.TextWrapped = false
		return card
	end
	local function need(card, x, iconKey, have, want, text)
		local ok = have >= want
		local holder = UI.new("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(150, 34), Position = UDim2.fromOffset(x, 86), ZIndex = 6}, card)
		UI.icon(holder, iconKey, UDim2.fromOffset(34, 34), nil, {ZIndex = 7})
		local label = UI.text(holder, text or (Config.Format(have) .. "/" .. Config.Format(want)), UDim2.new(1, -40, 1, 0), UDim2.fromOffset(40, 0), 21,
			ok and Color3.fromRGB(120, 255, 90) or C.White)
		label.TextWrapped = false
		return ok
	end
	function renderers.Upgrades(state)
		UI.list(scroll, 16)
		-- v28: the treadmill next to your spawn (run on it to train speed)
		local tLevel = state.TreadmillLevel or 1
		local tread, nextTread = Config.Treadmills[tLevel], Config.Treadmills[tLevel + 1]
		if tread then
			local card = upgradeCard(0, tread.Accent:Lerp(Color3.fromRGB(40, 40, 60), 0.25), tread.Name,
				"+" .. Config.FormatRate(tread.Gain) .. " speed/s" .. (nextTread and ("  >  +" .. Config.FormatRate(nextTread.Gain) .. "/s  (" .. nextTread.Name .. ")") or "  (max)"))
			UI.icon(card, "Shoe", UDim2.fromOffset(120, 120), UDim2.fromOffset(28, 28), {ZIndex = 6})
			local walk = math.floor((state.WalkSpeed or Config.WalkSpeedFor(state.SpeedPower or 0)) + 0.5)
			local now = UI.text(card, "Speed " .. walk .. "   ·   level " .. tLevel .. "/" .. #Config.Treadmills, UDim2.fromOffset(300, 22), UDim2.fromOffset(176, 130), 17, C.Soft)
			now.TextWrapped = false
			if nextTread then
				local ok = need(card, 176, "Coin", state.Coins or 0, nextTread.Cost, Config.Format(nextTread.Cost))
				local button = UI.button(card, "UPGRADE", C.Green, UDim2.fromOffset(200, 50), UDim2.new(1, -216, 1, -62), function() store.send("UpgradeTreadmill") end, {TextSize = 26})
				if not ok or state.Busy then UI.disable(button, true) end
			end
		end
		-- rocket
		local level = state.RocketLevel or 1
		local nextRocket = Config.Rockets[level + 1]
		local reach = {}
		for _, planet in ipairs(Config.PlanetOrder) do if planet.RequiredRange == level + 1 then table.insert(reach, planet.Name) end end
		local rocketCard = upgradeCard(1, Color3.fromRGB(255, 140, 40), Config.Rockets[level].Name,
			nextRocket and ("Next unlocks " .. (reach[1] or "a new world")) or "Reaches every galaxy")
		UI.icon(rocketCard, "Rocket", UDim2.fromOffset(130, 130), UDim2.fromOffset(22, 22), {ZIndex = 6})
		if nextRocket then
			local ok = need(rocketCard, 176, "Coin", state.Coins or 0, nextRocket.Cost, Config.Format(nextRocket.Cost))
			local button = UI.button(rocketCard, "UPGRADE", C.Green, UDim2.fromOffset(200, 50), UDim2.new(1, -216, 1, -62), function() store.send("UpgradeRocket") end, {TextSize = 26})
			if not ok or state.Busy then UI.disable(button, true) end
		end
		-- suit
		local suitLevel = state.SuitLevel or 1
		local nextSuit = Config.Suits[suitLevel + 1]
		local suitCard = upgradeCard(2, Color3.fromRGB(150, 90, 255), Config.Suits[suitLevel].Name .. " Helmet",
			"Air " .. (state.MaxOxygen or Config.Suits[suitLevel].Oxygen) .. (nextSuit and ("  >  " .. nextSuit.Oxygen) or "  (max)"))
		UI.icon(suitCard, "Helmet", UDim2.fromOffset(130, 130), UDim2.fromOffset(22, 22), {ZIndex = 6})
		if nextSuit then
			local ok = need(suitCard, 176, "Coin", state.Coins or 0, nextSuit.Cost, Config.Format(nextSuit.Cost))
			local button = UI.button(suitCard, "UPGRADE", C.Green, UDim2.fromOffset(200, 50), UDim2.new(1, -216, 1, -62), function() store.send("UpgradeSuit") end, {TextSize = 26})
			if not ok or state.Busy then UI.disable(button, true) end
		end
		-- cargo
		local cargoLevel = state.CargoLevel or 1
		local nextCargo = Config.Cargo[cargoLevel + 1]
		local cargoCard = upgradeCard(3, Color3.fromRGB(40, 150, 255), "Cargo x" .. (state.Capacity or 1),
			nextCargo and ("Next: " .. nextCargo.Capacity .. " eggs per trip") or "Maximum cargo")
		UI.icon(cargoCard, "EggBig", UDim2.fromOffset(120, 120), UDim2.fromOffset(28, 28), {ZIndex = 6})
		if nextCargo then
			local ok = need(cargoCard, 176, "Coin", state.Coins or 0, nextCargo.Cost, Config.Format(nextCargo.Cost))
			local button = UI.button(cargoCard, "UPGRADE", C.Green, UDim2.fromOffset(200, 50), UDim2.new(1, -216, 1, -62), function() store.send("UpgradeCargo") end, {TextSize = 26})
			if not ok or state.Busy then UI.disable(button, true) end
		end
		-- jetpack
		local jetLevel = state.JetpackLevel or 1
		local jet, nextJet = Config.Jetpacks[jetLevel], Config.Jetpacks[jetLevel + 1]
		local jetCard = upgradeCard(4, Color3.fromRGB(58, 196, 128), jet.Name .. " Jetpack",
			jet.FlightTime .. "s flight" .. (nextJet and ("  >  " .. nextJet.FlightTime .. "s, " .. nextJet.Recharge .. "s recharge") or "  (max)"))
		UI.icon(jetCard, "JetpackIcon", UDim2.fromOffset(130, 130), UDim2.fromOffset(22, 22), {ZIndex = 6})
		if nextJet then
			local ok = need(jetCard, 176, "Coin", state.Coins or 0, nextJet.Cost, Config.Format(nextJet.Cost))
			local button = UI.button(jetCard, "UPGRADE", C.Green, UDim2.fromOffset(200, 50), UDim2.new(1, -216, 1, -62), function() store.send("UpgradeJetpack") end, {TextSize = 26})
			if not ok or state.Busy then UI.disable(button, true) end
		end
	end

	-- v28: the trail shop (Steal an Egg style): every trail with its colours, how much faster you train with it,
	-- BUY (coins) / EQUIP / EQUIPPED
	function renderers.Trails(state)
		UI.list(scroll, 12)
		local worn = state.Trail ~= "" and Config.Trails[state.Trail or ""] or nil
		section(worn and ("Wearing: " .. worn.Name .. "  (x" .. worn.Mult .. " speed training)") or "Trails make you train speed faster on the treadmill!", 1,
			worn and C.Gold or C.Soft)
		local g = grid(2, 196, columns)
		for i, trail in ipairs(Config.TrailList) do
			local owned = state.Trails and state.Trails[trail.Id] == true
			local rarity = Config.Rarities[trail.Rarity] or Config.Rarities.Common
			local card = UI.card(g, rarity.Color, UDim2.new(), nil, "Trail_" .. trail.Id)
			card.LayoutOrder = i
			-- the streak itself
			local streak = UI.new("Frame", {Name = "Streak", BackgroundColor3 = C.White, Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 12), ZIndex = 6}, card)
			UI.round(streak, 20); UI.stroke(streak, 3, C.Ink)
			UI.new("UIGradient", {Color = Config.TrailColors(trail), Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.85, 0.15), NumberSequenceKeypoint.new(1, 0.7)})}, streak)
			local shine = UI.new("Frame", {BackgroundColor3 = C.White, BackgroundTransparency = 0.6, Size = UDim2.new(1, -20, 0.3, 0), Position = UDim2.new(0, 10, 0.12, 0), ZIndex = 7}, streak)
			UI.round(shine, 10)
			local name = UI.text(card, trail.Name, UDim2.new(1, -20, 0, 30), UDim2.fromOffset(10, 58), 25)
			name.TextXAlignment = Enum.TextXAlignment.Center; name.TextWrapped = false; name.TextScaled = true
			UI.new("UITextSizeConstraint", {MaxTextSize = 25}, name)
			local r = UI.text(card, string.upper(trail.Rarity), UDim2.new(1, -20, 0, 18), UDim2.fromOffset(10, 88), 15, rarity.Color:Lerp(C.White, 0.4))
			r.TextXAlignment = Enum.TextXAlignment.Center
			local mult = UI.text(card, "x" .. trail.Mult .. " speed training", UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, 106), 20, Color3.fromRGB(120, 255, 90))
			mult.TextXAlignment = Enum.TextXAlignment.Center
			local isWorn = state.Trail == trail.Id
			local label = isWorn and "EQUIPPED" or owned and "EQUIP" or Config.Format(trail.Cost)
			local button = UI.button(card, label, isWorn and C.Muted or owned and C.Blue or C.Green, UDim2.new(1, -24, 0, 46), UDim2.new(0, 12, 1, -56), function()
				if isWorn then store.send("EquipTrail", "")
				elseif owned then store.send("EquipTrail", trail.Id)
				else store.send("BuyTrail", trail.Id) end
			end, {TextSize = 24, Icon = (not owned) and "Coin" or nil, Name = "TrailButton"})
			if not owned and (state.Coins or 0) < trail.Cost then UI.disable(button, true) end
		end
	end

	function renderers.Test(state)
		UI.list(scroll, 10)
		section("Studio only", 1, C.Gold)
		local entries = {
			{"Rich mode", "DevGrant"}, {"All eggs", "DevEggs"}, {"All pets", "DevPets"}, {"Finish eggs", "DevReadyEggs"},
			{"Toggle passes", "DevPasses"}, {"Go home", "DevHome"}, {"Reset maps", "DevResetMaps"}, {"Meteor Run", "DevMinigame"},
			{"Meteor Shower", "DevEvent", "MeteorShower"}, {"Golden Hour", "DevEvent", "GoldenHour"}, {"Egg Storm", "DevEvent", "EggStorm"},
		}
		for _, planet in ipairs(Config.PlanetOrder) do table.insert(entries, {"Visit " .. planet.Name, "DevVisit", planet.Id}) end
		local g = grid(2, 64, 3)
		for i, entry in ipairs(entries) do
			local b = UI.button(g, entry[1], i <= 11 and C.Purple or C.Blue, UDim2.new(), nil, function()
				store.send(entry[2], entry[3])
				if entry[2] == "DevVisit" or entry[2] == "DevHome" then Menus.Close() end
			end, {TextSize = 22, Name = "Test" .. i})
			b.LayoutOrder = i
		end
	end

	-- ---------------------------------------------------------------- open/close
	local function tabs(key)
		local def = defs[key]
		tabBar.Visible = def.Tabs ~= nil
		scroll.Position = UDim2.fromOffset(12, def.Tabs and 116 or 64)
		scroll.Size = UDim2.new(1, -24, 1, def.Tabs and -128 or -76)
		if not def.Tabs then return end
		tab[key] = tab[key] or def.Tabs[1]
		for i, name in ipairs(def.Tabs) do
			local b = UI.button(tabBar, name, name == tab[key] and def.Color or C.Panel2, UDim2.fromOffset(i and 190 or 190, 42), nil, function()
				tab[key] = name; signature = ""; Menus.Render(); scroll.CanvasPosition = Vector2.zero
			end, {TextSize = 20, Name = "Tab" .. i})
			b.LayoutOrder = i
		end
	end
	function Menus.Render(keepScroll)
		if not active then return end
		local pos = scroll.CanvasPosition
		clear()
		local def = defs[active]
		title.Text = def.Title
		local state = store.state
		walletText.Text = Config.Format(state.Coins or 0)
		wallet.Visible = active == "Shop" or active == "Upgrades" or active == "Trails"
		tabs(active)
		scroll.Visible = active ~= "Index"; indexView.Visible = active == "Index"
		local ok, err = pcall(renderers[active], state)
		if not ok then warn("[PFE] menu " .. active .. ": " .. tostring(err)) end
		if keepScroll ~= false then scroll.CanvasPosition = pos end
	end
	local function layout()
		local camera = workspace.CurrentCamera
		if not camera then return end
		local vp = camera.ViewportSize
		local s = math.min((vp.X - 40) / 840, (vp.Y - 70) / 540, UI.isConsole() and 1.3 or 1.15)
		modalScale.Scale = math.max(0.4, s)
		local newColumns = vp.X < 700 and 2 or 3
		if newColumns ~= columns then columns = newColumns; if active then Menus.Render() end end
	end
	if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end
	layout()

	function Menus.Close()
		if not active then return end
		active = nil; modal.Visible = false; dim.Visible = false; signature = ""
		player:SetAttribute("PFEMenuOpen", false)
		UI.tween(blur, {Size = 0}, 0.18)
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(modal) then GuiService.SelectedObject = nil end
	end
	function Menus.Open(key)
		if not defs[key] or store.flying() or store.state.Busy then return end
		if key == "Test" and not store.state.DevMode then return end
		if Menus.Map then Menus.Map:Close() end
		active = key; modal.Visible = true; dim.Visible = true
		player:SetAttribute("PFEMenuOpen", true)
		local target = modalScale.Scale
		modalScale.Scale = target * 0.86; UI.tween(modalScale, {Scale = target}, 0.3, Enum.EasingStyle.Back)
		dim.BackgroundTransparency = 1; UI.tween(dim, {BackgroundTransparency = 0.5}, 0.2)
		UI.tween(blur, {Size = 12}, 0.22)
		Menus.Render(false)
		scroll.CanvasPosition = Vector2.zero
	end
	function Menus.Toggle(key)
		if active == key then Menus.Close() else Menus.Open(key) end
	end
	dim.Activated:Connect(Menus.Close)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then Menus.Close() end
	end)
	store.on(function(state)
		if not active then return end
		local relevant = {state.Coins, state.SuitLevel, state.RocketLevel, state.CargoLevel, state.JetpackLevel,
			#(state.Pets or {}), state.DiscoveredEggs, state.DiscoveredPets, state.Passes, state.Busy,
			state.TreadmillLevel, state.Trails, state.Trail, #(state.Eggs or {})}
		local ok, nextSignature = pcall(HttpService.JSONEncode, HttpService, relevant)
		if ok and nextSignature ~= signature then signature = nextSignature; Menus.Render() end
		if state.Busy then Menus.Close() end
	end)
	player:GetAttributeChangedSignal("PFEFlightActive"):Connect(function() if store.flying() then Menus.Close() end end)

	-- ---------------------------------------------------------------- galaxy map
	Menus.Map = PlanetMap.new({Player = player, Config = Config, UI = UI, Send = store.send,
		OnOpened = function() Menus.Close() end, OnClosed = function() end})
	store.on(function(state) Menus.Map:Update(state) end)
	function Menus.OpenMap() Menus.Close(); Menus.Map:Open(store.state) end
end

return Menus
