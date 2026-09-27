-- Click sounds for every interface button (shop, rooms, admin panel, HUD, title).
local Players=game:GetService('Players')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local shared=ReplicatedStorage:WaitForChild('ArmyRoundShared',20)
if not shared then return end
local UISound=require(shared:WaitForChild('UISound'))
UISound.init(Players.LocalPlayer:WaitForChild('PlayerGui'))
