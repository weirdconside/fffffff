--!nocheck
-- (v35) Who a bot is: a made-up name (never a real account's), an avatar dressed from Roblox's free catalog, the
-- animations it walks with and the habits it plays with.
--  * Animations: about half of real players wear one of Roblox's animation packages (often mixed: one pack's idle,
--    another's run), the rest the default R15 set. Every id below is a Roblox-made animation (creator Roblox, id 1),
--    checked against economy.roblox.com on 2026-10-06, so they play in any game.
--  * Habits (Persona): how good it is, how greedy and how mean, what it plays on (keyboard, phone, gamepad), whether it
--    uses shift lock, how often it jumps for no reason, how good its connection is, how far into the game it is.
local Looks = {}
local rng = Random.new()

local function pick(list) return list[rng:NextInteger(1, #list)] end
Looks.Pick = pick

-- ---------------------------------------------------------------- the avatar (free Roblox-made catalog items, fetched 2026-10-05)
local BODY_OUTFITS = {131830047, 131929365, 2219390889, 131830046, 1992514177, 11999909414, 131830049, 2273580660, 4886052516, 4793835913,
	131929496, 131929497, 131830048, 1992500252, 12005855118, 320899613, 131929363, 3314419321, 1545219396, 131830044, 12005811353, 11999916658,
	12092458560, 1545101850, 12093157062, 12151441216, 12006364043, 12139530821, 12013400311, 12006493372, 12120409403, 12109442982,
	12010906903, 12103090750, 12102387230}
local HAIR = {1103003368, 2956239660, 451221329, 63690008, 451220849, 9243992729, 9244021842, 3814474927, 376524487, 376526888, 9174355709,
	7193442167, 7193448258, 3814476174, 9244095135, 9174354743, 9243987340, 9244089488, 7193386173, 9244097555, 6993754725, 7193401217,
	9244038785, 7193450455, 7193445686, 7193448988, 9244111257, 7193449810, 7193444640, 376527350, 9244057408, 9174353649, 7193405096,
	6993758617, 7193419595, 7193424874, 9244148336, 9244067444, 9244114211, 9244122897, 9244125859, 9244070571, 376548738, 7193397693,
	9244060144, 9243995099, 9244145658, 9244024443, 9244033194, 9244029916, 7193437847, 9243976603, 9244008307, 9244064248, 7193454569,
	7193451306, 9244010432, 9244091757, 9244134513, 9244150641, 62234425, 9243983205, 9244014391, 9244131570, 9244082349, 7193452166,
	7193455510, 9244137452}
local HATS = {417457461, 607702162, 2646473721, 607700713, 617605556, 1772336109, 48474313, 4819740796, 3403874988, 4047554959, 3438342658,
	4094878701, 3992084515, 4324158403, 4489239608, 3033908130, 3033910400, 3940375351, 4391384843, 4246228452, 3443038622, 3662265036,
	3822880197, 3499972183, 3398308134, 3656493304, 3409612660, 4645404679, 4584042059, 4154538250, 4645400486, 4381707497, 4622081834, 4584029953}
local SHIRTS = {607785314, 3670737444, 144076358, 398633584, 382538059, 398635081, 398634295, 4047886060, 4047884939, 4047884046, 144076436,
	382537702, 382538295, 382537085}
local PANTS = {398633812, 398635338, 398634487, 144076760, 382538503, 382537569, 382537950, 382537806}
local JACKETS = {7192553841, 8648380153, 7192549218, 8516609675, 8516620262, 8648389231, 8516612751, 6984765766, 7192546798, 8648397446,
	7192547628, 8516648620, 6984767443, 8516638468, 8516655378}
local TSHIRTS3D = {7178736794, 9112474888, 9120031517, 7178740556, 7178737816, 9119670803, 9112483644}
local PANTS3D = {6984763785, 9120251003, 7192664790, 6984740059, 7192681239, 8721985925}
local SWEATERS3D = {9240757332, 6984769289, 9240758221}
local FACE_ACC = {376527500, 376526673}
local NECK_ACC = {376527115}
local SKIN = {Color3.fromRGB(255, 220, 177), Color3.fromRGB(241, 194, 125), Color3.fromRGB(224, 172, 105), Color3.fromRGB(198, 134, 66),
	Color3.fromRGB(141, 85, 36), Color3.fromRGB(255, 204, 153), Color3.fromRGB(234, 184, 146), Color3.fromRGB(110, 66, 40)}

function Looks.Describe()
	local desc
	local ok = pcall(function() desc = game:GetService("Players"):GetHumanoidDescriptionFromOutfitId(pick(BODY_OUTFITS)) end)
	if not ok or not desc then desc = Instance.new("HumanoidDescription") end
	if rng:NextNumber() < 0.6 then
		local skin = pick(SKIN)
		desc.HeadColor = skin; desc.LeftArmColor = skin; desc.RightArmColor = skin; desc.TorsoColor = skin
		desc.LeftLegColor = skin; desc.RightLegColor = skin
	end
	desc.HairAccessory = tostring(pick(HAIR))
	desc.HatAccessory = rng:NextNumber() < 0.35 and tostring(pick(HATS)) or ""
	desc.FaceAccessory = rng:NextNumber() < 0.15 and tostring(pick(FACE_ACC)) or ""
	desc.NeckAccessory = rng:NextNumber() < 0.08 and tostring(pick(NECK_ACC)) or ""
	-- clothes: classic, or the newer layered ones
	if rng:NextNumber() < 0.5 then
		desc.Shirt = pick(SHIRTS); desc.Pants = pick(PANTS)
	else
		local layered = {}
		local top = rng:NextNumber()
		if top < 0.4 then table.insert(layered, {AssetId = pick(JACKETS), AccessoryType = Enum.AccessoryType.Jacket, IsLayered = true, Order = 3})
		elseif top < 0.75 then table.insert(layered, {AssetId = pick(TSHIRTS3D), AccessoryType = Enum.AccessoryType.TShirt, IsLayered = true, Order = 1})
		else table.insert(layered, {AssetId = pick(SWEATERS3D), AccessoryType = Enum.AccessoryType.Sweater, IsLayered = true, Order = 2}) end
		table.insert(layered, {AssetId = pick(PANTS3D), AccessoryType = Enum.AccessoryType.Pants, IsLayered = true, Order = 4})
		-- (false: the layered clothes only - true would wipe the hair / hat / face / neck accessories set above)
		pcall(function() desc:SetAccessories(layered, false) end)
		if rng:NextNumber() < 0.5 then desc.Pants = pick(PANTS) end
	end
	desc.HeightScale = rng:NextNumber(0.92, 1.05); desc.WidthScale = rng:NextNumber(0.8, 1)
	desc.HeadScale = rng:NextNumber(0.95, 1.05)
	return desc
end

-- ---------------------------------------------------------------- names
-- made up the way people really pick them (never a real account's name; a published game never borrows one)
local SYL = {"ka", "ri", "mo", "na", "to", "vi", "sa", "li", "ko", "da", "mi", "ra", "ni", "po", "ze", "lu", "ta", "ve", "bo", "ki", "ya", "me"}
local WORDS = {"shadow", "nova", "pixel", "frosty", "lucky", "ninja", "panda", "dino", "pumpkin", "neon", "comet", "kitty", "bunny",
	"wolfie", "cookie", "mango", "berry", "storm", "blaze", "ghost", "sushi", "candy", "boba", "toast", "nugget", "cosmo", "astro", "kiwi",
	"egg", "noob", "pro", "gamer", "sky", "star", "moon", "fox", "bear", "tiger", "shark", "dragon", "cat", "dog", "pug", "duck", "frog",
	"slime", "cupcake", "taco", "pizza", "rocket", "robo", "zombie", "hero", "king", "queen", "princess", "boy", "girl", "kid", "legend"}
local ADJ = {"epic", "super", "mega", "cool", "lil", "big", "tiny", "the", "real", "its", "not", "silly", "crazy", "sweet", "dark", "cute",
	"fast", "happy", "sad", "mr", "ms", "xx", "iam", "just"}
local TAILS = {"_yt", "_pro", "_tt", "_rblx", "xd", "_x", "_official", "_gg", "_play", "_2k", "_ttv", "", "", "", "", "", "", ""}
local DISPLAY = {"Luna", "Sam", "Kai", "Mia", "Leo", "Zoe", "Max", "Ava", "Eli", "Nina", "Ollie", "Ruby", "Finn", "Ivy", "Jay", "Lily",
	"Milo", "Nova", "Theo", "Ella", "Toby", "Rosie", "Jack", "Lexi", "Noah", "Bella", "Rex", "Kira", "Alex", "Sky", "pixel", "dino",
	"bunny", "ghost", "egg", "toast", "nugget", "kitty", "astro", "comet", "mango", "boba", "cookie", "ninja", "panda", "frog", "duck"}
local function cap(s) return string.upper(string.sub(s, 1, 1)) .. string.sub(s, 2) end
local function syl(n)
	local out = ""
	for _ = 1, n do out ..= pick(SYL) end
	return out
end
function Looks.Name()
	local word, word2 = pick(WORDS), pick(WORDS)
	local year = tostring(rng:NextInteger(2008, 2017))
	local num = tostring(rng:NextInteger(1, 9999))
	local style = rng:NextInteger(1, 14)
	local name
	if style == 1 then name = syl(rng:NextInteger(2, 3)) .. num
	elseif style == 2 then name = word .. "_" .. syl(2) .. rng:NextInteger(1, 99)
	elseif style == 3 then name = cap(word) .. syl(1) .. num
	elseif style == 4 then name = "xX" .. cap(word) .. cap(word2) .. "Xx"
	elseif style == 5 then name = syl(2) .. "_" .. word .. pick(TAILS)
	elseif style == 6 then name = string.upper(syl(2)) .. "_" .. string.upper(word) .. rng:NextInteger(1, 9)
	elseif style == 7 then name = word .. syl(1) .. string.rep(tostring(rng:NextInteger(1, 9)), rng:NextInteger(2, 4))
	elseif style == 8 then name = cap(word) .. cap(word2) .. year
	elseif style == 9 then name = pick(ADJ) .. word .. num
	elseif style == 10 then name = cap(pick(ADJ)) .. "_" .. cap(word) .. pick(TAILS)
	elseif style == 11 then name = word .. word2 .. rng:NextInteger(10, 999)
	elseif style == 12 then name = cap(syl(rng:NextInteger(2, 3))) .. "_" .. year
	elseif style == 13 then name = word .. "_" .. word2 .. "_" .. rng:NextInteger(1, 99)
	else name = cap(string.sub(syl(1), 1, 1)) .. string.sub(syl(3), 2) .. pick(TAILS) end
	name = string.gsub(name, "__+", "_")
	if string.sub(name, 1, 1) == "_" then name = string.sub(name, 2) end
	return string.sub(name, 1, 20)
end
-- the name over its head and in the Tab list: like Roblox, usually the username itself, sometimes a display name
function Looks.DisplayName(username)
	local roll = rng:NextNumber()
	if roll < 0.62 then return username end
	if roll < 0.85 then return pick(DISPLAY) end
	return pick(DISPLAY) .. pick({"!", "", "<3", "XD", " :)", "_", "~", "7", "x"})
end

-- ---------------------------------------------------------------- animations
-- the default R15 set real players get (StarterCharacter's Animate: idle 9:1, Mocap walk / run ...)
Looks.DEFAULT_ANIMS = {
	idle = {{507766388, 9}, {507766666, 1}}, walk = 913402848, run = 913376220, jump = 507765000, fall = 507767968,
	climb = 507765644, swim = 913384386, swimidle = 913389285, sit = 2506281703,
	toolnone = 507768375, toolslash = 522635514, toollunge = 522638767,
}
-- Roblox's own animation packages (idle, its look-around, walk, run, jump, fall, climb) and how common each one is
local PACKS = {
	{"Rthro", 18, {2510196951, 2510197257}, 2510202577, 2510198475, 2510197830, 2510195892, 2510192778},
	{"Adidas", 10, {18537376492, 18537371272}, 18537392113, 18537384940, 18537380791, 18537367238, 18537363391},
	{"Stylish", 8, {616136790, 616138447}, 616146177, 616140816, 616139451, 616134815, 616133594},
	{"Ninja", 8, {656117400, 656118341}, 656121766, 656118852, 656117878, 656115606, 656114359},
	{"Mage", 7, {707742142, 707855907}, 707897309, 707861613, 707853694, 707829716, 707826056},
	{"Zombie", 7, {616158929, 616160636}, 616168032, 616163682, 616161997, 616157476, 616156119},
	{"Oldschool", 6, {5319828216, 5319831086}, 5319847204, 5319844329, 5319841935, 5319839762, 5319816685},
	{"Toy", 6, {782841498, 782845736}, 782843345, 782842708, 782847020, 782846423, 782843869},
	{"Cartoony", 6, {742637544, 742638445}, 742640026, 742638842, 742637942, 742637151, 742636889},
	{"Robot", 5, {616088211, 616089559}, 616095330, 616091570, 616090535, 616087089, 616086039},
	{"Superhero", 5, {616111295, 616113536}, 616122287, 616117076, 616115533, 616108001, 616104706},
	{"Levitation", 5, {616006778, 616008087}, 616013216, 616010382, 616008936, 616005863, 616003713},
	{"Bubbly", 4, {910004836, 910009958}, 910034870, 910025107, 910016857, 910001910, 909997997},
	{"Werewolf", 4, {1083195517, 1083214717}, 1083178339, 1083216690, 1083218792, 1083189019, 1083182000},
	{"Vampire", 4, {1083445855, 1083450166}, 1083473930, 1083462077, 1083455352, 1083443587, 1083439238},
	{"Confident", 4, {1069977950, 1069987858}, 1070017263, 1070001516, 1069984524, 1069973677, 1069946257},
	{"Elder", 3, {845397899, 845400520}, 845403856, 845386501, 845398858, 845396048, 845392038},
	{"Knight", 3, {657595757, 657568135}, 657552124, 657564596, 658409194, 657600338, 658360781},
	{"Astronaut", 3, {891621366, 891633237}, 891667138, 891636393, 891627522, 891617961, 891609353},
	{"Popstar", 3, {1212900985}, 1212980338, 1212980348, 1212954642, 1212900995, 1213044953},
	{"Sneaky", 3, {1132473842, 1132477671}, 1132510133, 1132494274, 1132489853, 1132469004, 1132461372},
	{"Pirate", 2, {750781874, 750782770}, 750785693, 750783738, 750782230, 750780242, 750779899},
	{"Princess", 2, {941003647, 941013098}, 941028902, 941015281, 941008832, 941000007, 940996062},
	{"Cowboy", 2, {1014390418, 1014398616}, 1014421541, 1014401683, 1014394726, 1014384571, 1014380606},
	{"Patrol", 2, {1149612882, 1150842221}, 1151231493, 1150967949, 1150944216, 1148863382, 1148811837},
}
Looks.PACKS = PACKS
local function rollPack()
	local total = 0
	for _, p in ipairs(PACKS) do total += p[2] end
	local roll = rng:NextNumber() * total
	for _, p in ipairs(PACKS) do
		roll -= p[2]
		if roll <= 0 then return p end
	end
	return PACKS[1]
end
local function idleOf(pack)
	local list = {{pack[3][1], 9}}
	if pack[3][2] then table.insert(list, {pack[3][2], 1}) end
	return list
end
-- the animations this bot walks with: the default set, one pack, or a mix of packs (and their names, for the tests)
function Looks.Animations()
	local set = table.clone(Looks.DEFAULT_ANIMS)
	local roll = rng:NextNumber()
	if roll < 0.5 then return set, "Default" end
	local main = rollPack()
	set.idle, set.walk, set.run, set.jump, set.fall, set.climb = idleOf(main), main[4], main[5], main[6], main[7], main[8]
	if roll < 0.82 then return set, main[1] end
	-- mixed: another pack's idle, or its jump and fall, or its walk and run (people buy them one by one)
	local other = rollPack()
	local part = rng:NextInteger(1, 3)
	if part == 1 then set.idle = idleOf(other)
	elseif part == 2 then set.jump, set.fall = other[6], other[7]
	else set.walk, set.run = other[4], other[5] end
	return set, main[1] .. "+" .. other[1]
end

-- ---------------------------------------------------------------- habits
local function between(a, b) return a + (b - a) * rng:NextNumber() end
function Looks.Persona()
	local p = {}
	-- how well it plays (reaction, routes, aim, judging the air)
	p.Skill = math.clamp(between(0.15, 1) ^ 0.8, 0.1, 1)
	p.Greed = between(0.2, 1)                         -- eggs: stealing, racing for the rare ones
	p.Aggression = between(0, 1) ^ 1.3                -- bonking people for fun, defending, revenge
	p.Focus = between(0.3, 1)                         -- low focus: goes AFK, wanders off, gets distracted
	local j = rng:NextNumber()
	p.Jumpiness = j < 0.5 and between(0.01, 0.08) or j < 0.85 and between(0.15, 0.5) or between(0.9, 2.2)
	local input = rng:NextNumber()
	p.Input = input < 0.62 and "Keyboard" or input < 0.95 and "Touch" or "Gamepad"
	p.ShiftLock = p.Input == "Keyboard" and rng:NextNumber() < 0.38
	local ping = rng:NextNumber()
	p.Ping = ping < 0.6 and "Good" or ping < 0.9 and "Average" or "Bad"
	-- how far into the game it is (1 = new .. 6 = been at it for weeks)
	local tier = rng:NextNumber()
	p.Tier = tier < 0.18 and 1 or tier < 0.42 and 2 or tier < 0.66 and 3 or tier < 0.84 and 4 or tier < 0.95 and 5 or 6
	p.Reaction = between(0.18, 0.55) * (1.3 - p.Skill * 0.6)   -- seconds to notice and react
	p.Analog = between(0.82, 1)                               -- how far a thumb pushes the stick
	return p
end

return Looks
