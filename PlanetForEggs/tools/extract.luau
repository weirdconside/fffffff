-- lune run tools/extract.luau <place.rbxl> <outdir>
-- Dumps every script of a place into <outdir>, one file per script, folders mirroring the tree:
--   <outdir>/ServerScriptService/GameServer.server.lua, <outdir>/ServerScriptService/GameServer/Data.module.lua ...
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local place, outdir = process.args[1], process.args[2]
local game = roblox.deserializePlace(fs.readFile(place))
local SUFFIX = {Script = ".server.lua", LocalScript = ".client.lua", ModuleScript = ".module.lua"}
local count = 0
local function pathOf(inst)
	local parts = {}
	local node = inst
	while node and node ~= game do
		table.insert(parts, 1, node.Name)
		node = node.Parent
	end
	return parts
end
for _, d in game:GetDescendants() do
	local suffix = SUFFIX[d.ClassName]
	if suffix then
		local parts = pathOf(d)
		local dir = outdir
		for i = 1, #parts - 1 do dir ..= "/" .. parts[i] end
		fs.writeDir(dir)
		fs.writeFile(dir .. "/" .. parts[#parts] .. suffix, d.Source)
		count += 1
	end
end
print("extracted", count, "scripts")
