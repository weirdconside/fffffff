-- lune run tools/build.luau <original.rbxl> <scripts dir> <out.rbxl>
-- Rebuilds the place from the original file and the script folder made by extract.luau:
--  * every script file replaces the Source of the script at the same path;
--  * a file with no script at its path becomes a new script there (class from the suffix);
--  * every script in the result is compiled once (a syntax error stops the build).
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local luau = require("@lune/luau")

local placePath, dir, outPath = process.args[1], process.args[2], process.args[3]
local game = roblox.deserializePlace(fs.readFile(placePath))
local Instance = roblox.Instance

local CLASS = {server = "Script", client = "LocalScript", module = "ModuleScript"}

local function child(parent, name)
	for _, c in parent:GetChildren() do
		if c.Name == name then return c end
	end
	return nil
end

local changed, created, same = 0, 0, 0
local function walk(path, segments)
	for _, entry in fs.readDir(path) do
		local full = path .. "/" .. entry
		if fs.isDir(full) then
			local copy = table.clone(segments)
			table.insert(copy, entry)
			walk(full, copy)
		else
			local name, kind = string.match(entry, "^(.+)%.(%a+)%.lua$")
			assert(name and CLASS[kind], "bad script file name: " .. full)
			local parent = game
			for i, seg in segments do
				local nextNode = if i == 1 then game:FindFirstChildOfClass(seg) or child(game, seg) else child(parent, seg)
				if not nextNode then
					-- a plain Folder for a new branch (never for a service)
					assert(i > 1, "no service " .. seg)
					nextNode = Instance.new("Folder")
					nextNode.Name = seg
					nextNode.Parent = parent
				end
				parent = nextNode
			end
			local source = fs.readFile(full)
			local existing = child(parent, name)
			if existing and existing.ClassName == CLASS[kind] then
				if existing.Source ~= source then
					existing.Source = source
					changed += 1
				else
					same += 1
				end
			else
				assert(existing == nil, "a non-script instance is in the way: " .. full)
				local script = Instance.new(CLASS[kind])
				script.Name = name
				script.Source = source
				script.Parent = parent
				created += 1
			end
		end
	end
end
walk(dir, {})

-- every script must compile
local failures = 0
for _, d in game:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		local ok, err = pcall(luau.compile, d.Source)
		if not ok then
			failures += 1
			print("COMPILE ERROR in " .. d:GetFullName() .. ":\n" .. tostring(err))
		end
	end
end
if failures > 0 then
	print(failures .. " script(s) failed to compile - nothing written")
	process.exit(1)
end

fs.writeFile(outPath, roblox.serializePlace(game))
print(string.format("built %s: %d changed, %d new, %d unchanged scripts", outPath, changed, created, same))
