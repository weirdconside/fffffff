-- Source tables recovered from the supplied place. Server rules are new.
local Data = {}
Data.Components = (function()
local tbl_upv_1 = {}
local tbl_2 = {Description = "Trains your army. Every Barracks adds training speed; your best one unlocks new troops.", Order = 2, PerInstance = true, DisplayName = "Barracks"}
tbl_2.Levels = {
    [1] = {Stats = {TrainBonus = 0}, Perks = {"Trains Barbarians"}},
    [2] = {BuildTime = 15, Cost = {Stone = 25, Log = 75}, Stats = {TrainBonus = 0.25}, Perks = {"+25% training speed", "Unlocks Archers"}},
    [3] = {BuildTime = 40, Cost = {Log = 200, Stone = 75, ["Iron Bar"] = 10}, Stats = {TrainBonus = 0.5}, Perks = {"+50% training speed", "Unlocks Giants"}},
    [4] = {BuildTime = 5400, Cost = {Stone = 200, Gold = 40, Crystal = 15, Plank = 80}, Stats = {TrainBonus = 0.75}, Perks = {"+75% training speed", "Unlocks Wizards"}},
    [5] = {BuildTime = 14400, Cost = {Stone = 300, ["Iron Bar"] = 40, Gold = 120}, Stats = {TrainBonus = 1}, Perks = {"+100% training speed"}}
}
local tbl_3 = {Order = 3, Description = "The heart of your settlement. Upgrading it unlocks higher building levels.", DisplayName = "Townhall"}
tbl_3.Levels = {
    [1] = {Perks = {"Your settlement's heart"}},
    [2] = {BuildTime = 60, Cost = {Stone = 50, Log = 150}, Perks = {"Unlocks level 2 buildings"}},
    [3] = {BuildTime = 300, Cost = {Stone = 200, Log = 400, Gold = 10}, Perks = {"Unlocks level 3 buildings"}},
    [4] = {BuildTime = 7200, Cost = {Stone = 600, Gold = 50, Plank = 100}, Perks = {"Unlocks level 4 buildings"}},
    [5] = {BuildTime = 21600, Cost = {Plank = 250, Stone = 1000, ["Iron Bar"] = 40, Gold = 150}, Perks = {"Unlocks level 5 buildings", "Maximum townhall"}}
}
local tbl_4 = {Order = 4, Description = "Houses your builders.", DisplayName = "Builder Hut"}
tbl_4.Levels = {
    [1] = {Stats = {Builders = 1}, Perks = {"1 builder"}},
    [2] = {BuildTime = 30, Cost = {Stone = 50, Log = 100}, Stats = {Builders = 2}, Perks = {"2 builders"}},
    [3] = {BuildTime = 90, Cost = {Stone = 150, Log = 300}, Stats = {Builders = 3}, Perks = {"3 builders"}},
    [4] = {BuildTime = 7200, Cost = {Stone = 200, Gold = 60, Plank = 100}, Stats = {Builders = 4}, Perks = {"4 builders"}},
    [5] = {BuildTime = 14400, Cost = {Plank = 200, Stone = 400, ["Iron Bar"] = 25, Gold = 150}, Stats = {Builders = 5}, Perks = {"5 builders"}}
}
local tbl_5 = {Order = 5, Description = "Houses lumberjacks who chop trees automatically.", DisplayName = "Lumber Hut"}
tbl_5.Levels = {
    [1] = {Stats = {Storage = 60, Workers = 2}, Perks = {"2 lumberjacks", "Stores 60 logs"}},
    [2] = {BuildTime = 15, Cost = {Log = 60}, Stats = {Storage = 100, Workers = 3}, Perks = {"3 lumberjacks", "Stores 100 logs"}},
    [3] = {BuildTime = 120, Cost = {Stone = 100, Log = 200}, Stats = {Storage = 160, Workers = 4}, Perks = {"4 lumberjacks", "Stores 160 logs"}},
    [4] = {BuildTime = 3600, Cost = {Stone = 150, Gold = 30, Plank = 60}, Stats = {Storage = 240, Workers = 5}, Perks = {"5 lumberjacks", "Stores 240 logs"}},
    [5] = {BuildTime = 10800, Cost = {Plank = 150, Stone = 250, ["Iron Bar"] = 20, Gold = 90}, Stats = {Storage = 400, Workers = 6}, Perks = {"6 lumberjacks", "Stores 400 logs"}}
}
local tbl_6 = {Order = 6, Description = "Houses miners who quarry stone automatically.", DisplayName = "Miner Hut"}
tbl_6.Levels = {
    [1] = {Stats = {Storage = 60, Workers = 1}, Perks = {"1 miner", "Stores 60 stone"}},
    [2] = {BuildTime = 20, Cost = {Stone = 30, Log = 80}, Stats = {Storage = 100, Workers = 2}, Perks = {"2 miners", "Stores 100 stone"}},
    [3] = {BuildTime = 150, Cost = {Stone = 120, Log = 250}, Stats = {Storage = 160, Workers = 3}, Perks = {"3 miners", "Stores 160 stone"}},
    [4] = {BuildTime = 3600, Cost = {Stone = 150, Gold = 35, Plank = 70}, Stats = {Storage = 240, Workers = 4}, Perks = {"4 miners", "Stores 240 stone"}},
    [5] = {BuildTime = 10800, Cost = {Plank = 170, Stone = 250, ["Iron Bar"] = 25, Gold = 100}, Stats = {Storage = 400, Workers = 5}, Perks = {"5 miners", "Stores 400 stone"}}
}
local tbl_7 = {Order = 7, Description = "Houses miners who dig iron ore automatically.", DisplayName = "Ore Miner Hut"}
tbl_7.Levels = {
    [1] = {Stats = {Storage = 60, Workers = 1}, Perks = {"1 ore miner", "Stores 60 ore"}},
    [2] = {BuildTime = 1800, Cost = {Stone = 100, Gold = 20, Plank = 40}, Stats = {Storage = 120, Workers = 2}, Perks = {"2 ore miners", "Stores 120 ore"}},
    [3] = {BuildTime = 7200, Cost = {Stone = 200, Gold = 60, Plank = 100}, Stats = {Storage = 200, Workers = 3}, Perks = {"3 ore miners", "Stores 200 ore"}},
    [4] = {BuildTime = 14400, Cost = {Stone = 300, ["Iron Bar"] = 30, Gold = 150}, Stats = {Storage = 300, Workers = 4}, Perks = {"4 ore miners", "Stores 300 ore"}}
}
local tbl_8 = {Order = 8, Description = "Houses miners who harvest crystal automatically.", DisplayName = "Crystal Miner Hut"}
tbl_8.Levels = {[1] = {Stats = {Storage = 60, Workers = 1}, Perks = {"1 crystal miner", "Stores 60 crystal"}}, [2] = {BuildTime = 7200, Cost = {Stone = 200, ["Iron Bar"] = 20, Gold = 80}, Stats = {Storage = 120, Workers = 2}, Perks = {"2 crystal miners", "Stores 120 crystal"}}, [3] = {BuildTime = 21600, Cost = {Stone = 300, ["Iron Bar"] = 50, Crystal = 40, Gold = 200}, Stats = {Storage = 200, Workers = 3}, Perks = {"3 crystal miners", "Stores 200 crystal"}}}
local tbl_9 = {Order = 9, Description = "Saws logs into planks. Walk in to queue crafts.", DisplayName = "Sawmill"}
tbl_9.Levels = {
    [1] = {Stats = {CraftSpeed = 1}, Perks = {"Crafts planks"}},
    [2] = {BuildTime = 300, Cost = {Stone = 100, Log = 200}, Stats = {CraftSpeed = 1.25}, Perks = {"25% faster crafting"}},
    [3] = {BuildTime = 3600, Cost = {Stone = 400, Gold = 20}, Stats = {CraftSpeed = 1.5}, Perks = {"50% faster crafting"}},
    [4] = {BuildTime = 10800, Cost = {Stone = 250, Gold = 60, Plank = 120}, Stats = {CraftSpeed = 2}, Perks = {"Double crafting speed"}},
    [5] = {BuildTime = 21600, Cost = {Plank = 250, Stone = 400, ["Iron Bar"] = 30, Gold = 150}, Stats = {CraftSpeed = 2.5}, Perks = {"2.5x crafting speed"}}
}
local tbl_10 = {Order = 10, Description = "Smelts iron ore into iron bars. Walk in to queue crafts.", DisplayName = "Foundry"}
tbl_10.Levels = {
    [1] = {Stats = {CraftSpeed = 1}, Perks = {"Smelts iron bars"}},
    [2] = {BuildTime = 1800, Cost = {Stone = 150, Gold = 30, Plank = 50}, Stats = {CraftSpeed = 1.25}, Perks = {"25% faster smelting"}},
    [3] = {BuildTime = 7200, Cost = {Stone = 250, Gold = 80, Plank = 120}, Stats = {CraftSpeed = 1.5}, Perks = {"50% faster smelting"}},
    [4] = {BuildTime = 21600, Cost = {Stone = 350, ["Iron Bar"] = 50, Crystal = 30, Gold = 200}, Stats = {CraftSpeed = 2}, Perks = {"Double smelting speed"}}
}
local tbl_11 = {Order = 11, Description = "Researches troop upgrades using trophies from enemy camps.", DisplayName = "Training Camp"}
tbl_11.Levels = {[1] = {Stats = {ResearchSpeed = 1}, Perks = {"Researches troop levels"}}, [2] = {BuildTime = 3600, Cost = {Stone = 200, Gold = 50, Plank = 100}, Stats = {ResearchSpeed = 1.25}, Perks = {"25% faster research"}}, [3] = {BuildTime = 14400, Cost = {Stone = 300, ["Iron Bar"] = 40, Gold = 150}, Stats = {ResearchSpeed = 1.5}, Perks = {"50% faster research"}}}
local tbl_12 = {Order = 12, Description = "Slowly generates gold. Walk over it to collect.", DisplayName = "Gold Mine"}
tbl_12.Levels = {
    [1] = {Stats = {GoldRate = 0.5, GoldCap = 10}, Perks = {"1 gold every 2 minutes", "Stores 10 gold"}},
    [2] = {BuildTime = 900, Cost = {Stone = 200, Gold = 10}, Stats = {GoldRate = 1, GoldCap = 25}, Perks = {"1 gold per minute", "Stores 25 gold"}},
    [3] = {BuildTime = 5400, Cost = {Stone = 200, Gold = 40, Plank = 80}, Stats = {GoldRate = 2, GoldCap = 50}, Perks = {"2 gold per minute", "Stores 50 gold"}},
    [4] = {BuildTime = 14400, Cost = {Stone = 300, ["Iron Bar"] = 30, Gold = 150}, Stats = {GoldRate = 3, GoldCap = 100}, Perks = {"3 gold per minute", "Stores 100 gold"}},
    [5] = {BuildTime = 21600, Cost = {Stone = 500, ["Iron Bar"] = 50, Crystal = 20, Gold = 300}, Stats = {GoldRate = 5, GoldCap = 150}, Perks = {"5 gold per minute", "Stores 150 gold"}}
}
tbl_upv_1.Components = {
    Campsite = {
        Description = "Home base for your troops. Upgrades raise this camp's housing.",
        Order = 1,
        PerInstance = true,
        DisplayName = "Campsite",
        Levels = {
            [1] = {Stats = {Capacity = 10}, Perks = {"Houses 10 units"}},
            [2] = {BuildTime = 10, Cost = {Log = 50}, Stats = {Capacity = 14}, Perks = {"Houses 14 units"}},
            [3] = {BuildTime = 120, Cost = {Stone = 50, Log = 150}, Stats = {Capacity = 18}, Perks = {"Houses 18 units"}},
            [4] = {BuildTime = 3600, Cost = {Stone = 150, Gold = 30, Plank = 60}, Stats = {Capacity = 24}, Perks = {"Houses 24 units"}},
            [5] = {BuildTime = 10800, Cost = {Plank = 150, Stone = 350, ["Iron Bar"] = 20, Gold = 90}, Stats = {Capacity = 30}, Perks = {"Houses 30 units"}}
        }
    },
    Barracks = tbl_2,
    Townhall = tbl_3,
    BuilderHut = tbl_4,
    LumberHut = tbl_5,
    MinerHut = tbl_6,
    OreMinerHut = tbl_7,
    CrystalMinerHut = tbl_8,
    Sawmill = tbl_9,
    Foundry = tbl_10,
    TrainingCamp = tbl_11,
    GoldMine = tbl_12
}
local tbl_13 = {}
tbl_13[2] = 1
local tbl_14 = {}
tbl_14[2] = 3
tbl_14[3] = 4
tbl_14[4] = 5
local tbl_15 = {}
tbl_15[2] = 3
tbl_15[3] = 4
local tbl_16 = {}
tbl_16[2] = 3
tbl_16[3] = 4
tbl_16[4] = 5
local tbl_17 = {}
tbl_17[2] = 4
tbl_17[3] = 5
tbl_upv_1.TownhallGate = {LumberHut = {[2] = 1}, Barracks = tbl_13, Foundry = tbl_14, TrainingCamp = tbl_15, OreMinerHut = tbl_16, CrystalMinerHut = tbl_17}
return tbl_upv_1
end)()
Data.Troops = (function()
local tbl_1 = {}
tbl_1.Troops = {
    Barbarian = {Order = 1, Icon = "", DisplayName = "Barbarian", Trophies = 1, WalkSpeed = 5.2, Units = 1, Entity = "Barbarian", TrainTime = 3, HP = 35, Damage = 5, Costs = {Log = 5}, Gradient = {Color3.fromRGB(224, 96, 34), Color3.fromRGB(255, 176, 102)}},
    Archer = {Order = 2, Icon = "", Trophies = 2, RequiresBarracks = 2, Projectile = "Arrow", Range = 12, DisplayName = "Archer", AggroRange = 14, WalkSpeed = 5.2, Units = 2, Entity = "Archer", TrainTime = 5, HP = 25, Damage = 7, Costs = {Stone = 10, Log = 15}, Gradient = {Color3.fromRGB(52, 158, 70), Color3.fromRGB(134, 232, 140)}},
    Giant = {Order = 3, RequiresBarracks = 3, Icon = "", AttackInterval = 2, DisplayName = "Giant", Trophies = 5, WalkSpeed = 3, Units = 4, Entity = "Giant", TrainTime = 15, HP = 200, Damage = 12, Costs = {["Iron Bar"] = 5, Log = 50, Stone = 30}, Gradient = {Color3.fromRGB(214, 148, 24), Color3.fromRGB(250, 212, 96)}},
    Wizard = {Order = 4, Range = 10, Splash = 6, Entity = "Wizard", TrainTime = 20, WalkSpeed = 5.2, Damage = 15, RequiresBarracks = 4, AttackInterval = 2, DisplayName = "Wizard", AggroRange = 12, Icon = "", Trophies = 5, Projectile = "Bolt", HP = 80, Units = 4, Costs = {Crystal = 10, ["Iron Bar"] = 5, Stone = 15}, Gradient = {Color3.fromRGB(158, 42, 226), Color3.fromRGB(226, 140, 252)}}
}
return tbl_1
end)()
Data.Craft = (function()
local tbl_upv_1 = {}
tbl_upv_1.Stations = {Sawmill = {Time = 5, MenuIcon = "rbxassetid://129857101252705", Output = "Plank", OutputAmount = 1, DisplayName = "Sawmill", Inputs = {Log = 4}}, Foundry = {Time = 13, MenuIcon = "rbxassetid://79453304955601", Output = "Iron Bar", OutputAmount = 1, DisplayName = "Foundry", Inputs = {["Iron Ore"] = 3, Stone = 6}}}
return tbl_upv_1
end)()
Data.Research = (function()
local tbl_upv_1 = {}
tbl_upv_1.StatMultPerLevel = 0.2
local tbl_2 = {}
tbl_2[2] = {Time = 900, Cost = {Plank = 30, Gold = 20, Trophy = 15}}
tbl_2[3] = {Time = 3600, Cost = {Trophy = 35, Gold = 60, ["Iron Bar"] = 15}}
local tbl_3 = {}
tbl_3[2] = {Time = 1800, Cost = {Trophy = 30, Gold = 50, ["Iron Bar"] = 20}}
tbl_3[3] = {Time = 5400, Cost = {Crystal = 20, Gold = 120, Trophy = 60}}
local tbl_4 = {}
tbl_4[2] = {Time = 2400, Cost = {Crystal = 25, Gold = 80, Trophy = 40}}
tbl_upv_1.Research = {Barbarian = {[2] = {Time = 600, Cost = {Log = 200, Gold = 10, Trophy = 5}}, [3] = {Time = 2700, Cost = {Plank = 40, Gold = 40, Trophy = 25}}}, Archer = tbl_2, Giant = tbl_3, Wizard = tbl_4}
local tbl_5 = {}
tbl_5[2] = 4
tbl_5[3] = 5
local tbl_6 = {}
tbl_6[2] = 5
tbl_upv_1.TownhallGate = {Archer = {[2] = 3, [3] = 4}, Giant = tbl_5, Wizard = tbl_6}
return tbl_upv_1
end)()
Data.Lands = {["S1"]={["pos"]={["x"]=0.0,["y"]=-0.775848388671875,["z"]=-14.86724853515625},["requires"]="",["cost"]={},["enemies"]={},["sourceId"]=22417},["S4"]={["pos"]={["x"]=-11.0,["y"]=-0.775848388671875,["z"]=-21.2115478515625},["requires"]="",["cost"]={},["enemies"]={},["sourceId"]=22434},["S3"]={["pos"]={["x"]=0.0,["y"]=-0.775848388671875,["z"]=-27.55584716796875},["requires"]="",["cost"]={},["enemies"]={},["sourceId"]=22451},["S7"]={["pos"]={["x"]=0.0,["y"]=-0.775848388671875,["z"]=-40.23968505859375},["requires"]="S3",["cost"]={["Log"]=80.0},["enemies"]={},["sourceId"]=22468},["S6"]={["pos"]={["x"]=11.0,["y"]=-0.775848388671875,["z"]=-33.89776611328125},["requires"]="S9",["cost"]={["Log"]=60.0},["enemies"]={},["sourceId"]=22487},["S2"]={["pos"]={["x"]=11.0,["y"]=-0.775848388671875,["z"]=-21.2115478515625},["requires"]="",["cost"]={},["enemies"]={},["sourceId"]=22506},["S8"]={["pos"]={["x"]=0.0,["y"]=-0.775848388671875,["z"]=-52.92425537109375},["requires"]="S13",["cost"]={["Stone"]=200.0,["Log"]=100.0},["enemies"]={["Archer"]=4.0,["Barbarian"]=7.0},["sourceId"]=22523},["S9"]={["pos"]={["x"]=21.999908447265625,["y"]=-0.775848388671875,["z"]=-27.55584716796875},["requires"]="S2",["cost"]={["Log"]=40.0},["enemies"]={},["sourceId"]=22596},["S10"]={["pos"]={["x"]=-22.000091552734375,["y"]=-0.775848388671875,["z"]=-27.55584716796875},["requires"]="S5",["cost"]={["Stone"]=30.0},["enemies"]={},["sourceId"]=22615},["S12"]={["pos"]={["x"]=-22.000091552734375,["y"]=-0.775848388671875,["z"]=-40.23974609375},["requires"]="S5",["cost"]={["Log"]=30.0},["enemies"]={["Barbarian"]=2.0},["sourceId"]=22634},["S11"]={["pos"]={["x"]=21.999908447265625,["y"]=-0.775848388671875,["z"]=-40.23974609375},["requires"]="S6",["cost"]={["Stone"]=30.0,["Log"]=100.0},["enemies"]={},["sourceId"]=22720},["S16"]={["pos"]={["x"]=-22.000091552734375,["y"]=-0.775848388671875,["z"]=-52.928466796875},["requires"]="S17",["cost"]={["Stone"]=300.0,["Gold"]=10.0},["enemies"]={["Barbarian"]=9.0,["Archer"]=1.0},["sourceId"]=22740},["S15"]={["pos"]={["x"]=21.999908447265625,["y"]=-0.775848388671875,["z"]=-52.928466796875},["requires"]="S14",["cost"]={["Stone"]=150.0,["Log"]=200.0,["Gold"]=5.0},["enemies"]={},["sourceId"]=22807},["S14"]={["pos"]={["x"]=10.99847412109375,["y"]=-0.775848388671875,["z"]=-46.58416748046875},["requires"]="S7",["cost"]={["Stone"]=150.0,["Log"]=250.0},["enemies"]={["Archer"]=3.0,["Barbarian"]=7.0},["sourceId"]=22828},["S17"]={["pos"]={["x"]=-10.996337890625,["y"]=-0.775848388671875,["z"]=-59.2685546875},["requires"]="S8",["cost"]={["Stone"]=250.0,["Gold"]=8.0},["enemies"]={},["sourceId"]=22901},["S18"]={["pos"]={["x"]=10.99847412109375,["y"]=-0.775848388671875,["z"]=-59.2685546875},["requires"]="S15",["cost"]={["Gold"]=15.0,["Plank"]=20.0},["enemies"]={},["sourceId"]=22921},["S5"]={["pos"]={["x"]=-10.99652099609375,["y"]=-0.77630615234375,["z"]=-33.90576171875},["requires"]="S4",["cost"]={["Log"]=25.0},["enemies"]={},["sourceId"]=22941},["S13"]={["pos"]={["x"]=-10.989959716796875,["y"]=-0.775848388671875,["z"]=-46.57421875},["requires"]="S5",["cost"]={["Stone"]=100.0,["Log"]=150.0},["enemies"]={},["sourceId"]=22960},["S22"]={["pos"]={["x"]=0.0,["y"]=1.224151611328125,["z"]=-65.6104736328125},["requires"]="S20",["cost"]={["Iron Ore"]=90.0,["Gold"]=50.0},["enemies"]={["Archer"]=6.0,["Giant"]=2.0,["Barbarian"]=1.0},["sourceId"]=22980},["S24"]={["pos"]={["x"]=10.998626708984375,["y"]=-0.7748689651489258,["z"]=-71.95767211914062},["requires"]="S18",["cost"]={["Gold"]=75.0,["Iron Ore"]=100.0,["Plank"]=70.0},["enemies"]={["Archer"]=2.0,["Giant"]=2.0,["Barbarian"]=5.0},["sourceId"]=23061},["S25"]={["pos"]={["x"]=22.004226684570312,["y"]=1.224151611328125,["z"]=-65.6104736328125},["requires"]="S24",["cost"]={["Gold"]=90.0,["Iron Bar"]=20.0},["enemies"]={["Archer"]=5.0,["Wizard"]=2.0,["Barbarian"]=4.0},["sourceId"]=23143},["S23"]={["pos"]={["x"]=0.0,["y"]=1.224151611328125,["z"]=-78.29914855957031},["requires"]="S22",["cost"]={["Gold"]=60.0,["Iron Ore"]=80.0,["Plank"]=60.0},["enemies"]={},["sourceId"]=23226},["S20"]={["pos"]={["x"]=-10.996337890625,["y"]=1.224151611328125,["z"]=-71.95767211914062},["requires"]="S19",["cost"]={["Iron Ore"]=40.0,["Gold"]=30.0},["enemies"]={},["sourceId"]=23247},["S19"]={["pos"]={["x"]=-22.004058837890625,["y"]=1.224151611328125,["z"]=-65.6104736328125},["requires"]="S16",["cost"]={["Gold"]=20.0,["Plank"]=30.0},["enemies"]={["Archer"]=5.0,["Barbarian"]=7.0},["sourceId"]=23267},["S21"]={["pos"]={["x"]=-22.00408935546875,["y"]=1.224151611328125,["z"]=-78.29914855957031},["requires"]="S20",["cost"]={["Gold"]=40.0,["Iron Ore"]=60.0,["Plank"]=40.0},["enemies"]={},["sourceId"]=23349},["S29"]={["pos"]={["x"]=21.999908447265625,["y"]=-0.775848388671875,["z"]=-78.302001953125},["requires"]="S28",["cost"]={["Gold"]=240.0,["Iron Bar"]=40.0},["enemies"]={},["sourceId"]=23370},["S30"]={["pos"]={["x"]=21.999908447265625,["y"]=-0.775848388671875,["z"]=-90.99066162109375},["requires"]="S28",["cost"]={["Gold"]=300.0,["Plank"]=100.0,["Iron Bar"]=50.0},["enemies"]={["Giant"]=3.0,["Archer"]=6.0,["Wizard"]=3.0,["Barbarian"]=4.0},["sourceId"]=23390},["S28"]={["pos"]={["x"]=11.00048828125,["y"]=-0.775848388671875,["z"]=-84.6439208984375},["requires"]="S27",["cost"]={["Gold"]=180.0,["Plank"]=80.0,["Iron Bar"]=30.0},["enemies"]={},["sourceId"]=23498},["S26"]={["pos"]={["x"]=-10.994476318359375,["y"]=-0.775848388671875,["z"]=-84.6439208984375},["requires"]="S23",["cost"]={["Gold"]=120.0,["Plank"]=60.0,["Iron Bar"]=25.0},["enemies"]={["Archer"]=6.0,["Giant"]=3.0,["Barbarian"]=4.0},["sourceId"]=23519},["S27"]={["pos"]={["x"]=-0.0011749267578125,["y"]=-0.775848388671875,["z"]=-90.99066162109375},["requires"]="S26",["cost"]={["Gold"]=150.0,["Iron Bar"]=25.0},["enemies"]={},["sourceId"]=23628},["S31"]={["pos"]={["x"]=11.00048828125,["y"]=-0.775848388671875,["z"]=-97.33258056640625},["requires"]="S27",["cost"]={["Gold"]=200.0,["Iron Bar"]=35.0},["enemies"]={},["sourceId"]=23648},["S32"]={["pos"]={["x"]=-10.9945068359375,["y"]=-0.775848388671875,["z"]=-97.33258056640625},["requires"]="S27",["cost"]={["Gold"]=200.0,["Plank"]=80.0,["Iron Bar"]=35.0},["enemies"]={},["sourceId"]=23668},["S33"]={["pos"]={["x"]=-22.005264282226562,["y"]=-0.775848388671875,["z"]=-90.99066162109375},["requires"]="S32",["cost"]={["Gold"]=260.0,["Iron Bar"]=45.0},["enemies"]={},["sourceId"]=23689}}
Data.Buildings = {["B23827"]={["kind"]="Campsite",["pos"]={["x"]=0.0,["y"]=-2.022879719734192,["z"]=-27.58050537109375},["land"]="S3",["sourceId"]=23827},["B23854"]={["kind"]="Townhall",["pos"]={["x"]=1.52587890625e-05,["y"]=-0.5000074505805969,["z"]=-14.51025390625},["land"]="S1",["sourceId"]=23854},["B23866"]={["kind"]="LumberHut",["pos"]={["x"]=14.466064453125,["y"]=-0.503509521484375,["z"]=-18.10296630859375},["land"]="S2",["sourceId"]=23866},["B23989"]={["kind"]="Barracks",["pos"]={["x"]=-13.944732666015625,["y"]=-0.42575836181640625,["z"]=-29.24724578857422},["land"]="S5",["sourceId"]=23989},["B24029"]={["kind"]="BuilderHut",["pos"]={["x"]=22.1708984375,["y"]=-0.454498291015625,["z"]=-23.14276123046875},["land"]="S9",["sourceId"]=24029},["B24072"]={["kind"]="GoldMine",["pos"]={["x"]=-0.02294921875,["y"]=-0.021839141845703125,["z"]=-52.7052001953125},["land"]="S8",["sourceId"]=24072},["B24128"]={["kind"]="OreMinerHut",["pos"]={["x"]=-17.76324462890625,["y"]=1.5741405487060547,["z"]=-64.00518798828125},["land"]="S19",["sourceId"]=24128},["B24174"]={["kind"]="MinerHut",["pos"]={["x"]=-25.434051513671875,["y"]=-0.4322948455810547,["z"]=-41.66893768310547},["land"]="S12",["sourceId"]=24174},["B24210"]={["kind"]="Sawmill",["pos"]={["x"]=10.038101196289062,["y"]=-0.42574596405029297,["z"]=-44.865074157714844},["land"]="S14",["sourceId"]=24210},["B24264"]={["kind"]="Foundry",["pos"]={["x"]=7.3799285888671875,["y"]=-0.3162555694580078,["z"]=-74.48100280761719},["land"]="S24",["sourceId"]=24264},["B24344"]={["kind"]="Barracks",["pos"]={["x"]=-0.0119781494140625,["y"]=1.5206108093261719,["z"]=-82.58575439453125},["land"]="S23",["sourceId"]=24344},["B24384"]={["kind"]="Campsite",["pos"]={["x"]=0.00048828125,["y"]=-0.02325451374053955,["z"]=-65.610595703125},["land"]="S22",["sourceId"]=24384},["B24411"]={["kind"]="TrainingCamp",["pos"]={["x"]=22.004226684570312,["y"]=1.574254035949707,["z"]=-62.81001281738281},["land"]="S25",["sourceId"]=24411},["B24444"]={["kind"]="CrystalMinerHut",["pos"]={["x"]=-14.5738525390625,["y"]=-0.4106893539428711,["z"]=-81.42750549316406},["land"]="S26",["sourceId"]=24444}}
Data.ResourceNodes = {["R23710"]={["kind"]="Pine Tree",["pos"]={["x"]=-7.076019287109375,["y"]=-0.5,["z"]=-22.4615478515625},["land"]="S4",["sourceId"]=23710},["R23711"]={["kind"]="Pine Tree",["pos"]={["x"]=7.0760498046875,["y"]=-0.5,["z"]=-20.6514892578125},["land"]="S2",["sourceId"]=23711},["R23712"]={["kind"]="Pine Tree",["pos"]={["x"]=-8.38531494140625,["y"]=-0.5,["z"]=-16.5009765625},["land"]="S4",["sourceId"]=23712},["R23713"]={["kind"]="Pine Tree",["pos"]={["x"]=8.114501953125,["y"]=-0.5,["z"]=-24.43450927734375},["land"]="S2",["sourceId"]=23713},["R23714"]={["kind"]="Pine Tree",["pos"]={["x"]=8.601593017578125,["y"]=-0.5,["z"]=-22.15472412109375},["land"]="S2",["sourceId"]=23714},["R23715"]={["kind"]="Pine Tree",["pos"]={["x"]=5.787567138671875,["y"]=-0.5,["z"]=-22.935302734375},["land"]="S2",["sourceId"]=23715},["R23716"]={["kind"]="Pine Tree",["pos"]={["x"]=5.5760498046875,["y"]=-0.5,["z"]=-15.11724853515625},["land"]="S1",["sourceId"]=23716},["R23717"]={["kind"]="Pine Tree",["pos"]={["x"]=15.4901123046875,["y"]=-0.5,["z"]=-22.935302734375},["land"]="S2",["sourceId"]=23717},["R23718"]={["kind"]="Pine Tree",["pos"]={["x"]=15.4901123046875,["y"]=-0.5,["z"]=-30.4739990234375},["land"]="S6",["sourceId"]=23718},["R23719"]={["kind"]="Pine Tree",["pos"]={["x"]=-11.9798583984375,["y"]=-0.5003582172442975,["z"]=-38.15704345703125},["land"]="S5",["sourceId"]=23719},["R23720"]={["kind"]="Pine Tree",["pos"]={["x"]=-10.0987548828125,["y"]=-0.50018310546875,["z"]=-33.270263671875},["land"]="S5",["sourceId"]=23720},["R23721"]={["kind"]="Pine Tree",["pos"]={["x"]=-7.076080322265625,["y"]=-0.5,["z"]=-37.1453857421875},["land"]="S5",["sourceId"]=23721},["R23722"]={["kind"]="Pine Tree",["pos"]={["x"]=-9.601593017578125,["y"]=-0.500244140625,["z"]=-37.31622314453125},["land"]="S5",["sourceId"]=23722},["R23723"]={["kind"]="Pine Tree",["pos"]={["x"]=-25.93194580078125,["y"]=-0.49999773333547637,["z"]=-24.83013916015625},["land"]="S10",["sourceId"]=23723},["R23724"]={["kind"]="Pine Tree",["pos"]={["x"]=-21.331451416015625,["y"]=-0.499664306640625,["z"]=-22.3292236328125},["land"]="S10",["sourceId"]=23724},["R23725"]={["kind"]="Pine Tree",["pos"]={["x"]=-18.250091552734375,["y"]=-0.500152587890625,["z"]=-25.30584716796875},["land"]="S10",["sourceId"]=23725},["R23726"]={["kind"]="Pine Tree",["pos"]={["x"]=-23.576141357421875,["y"]=-0.499847412109375,["z"]=-25.73199462890625},["land"]="S10",["sourceId"]=23726},["R23727"]={["kind"]="Stone",["pos"]={["x"]=-18.02056884765625,["y"]=-0.4997545558235288,["z"]=-43.35121154785156},["land"]="S12",["sourceId"]=23727},["R23728"]={["kind"]="Stone",["pos"]={["x"]=-24.58258056640625,["y"]=-0.499755859375,["z"]=-36.13983154296875},["land"]="S12",["sourceId"]=23728},["R23729"]={["kind"]="Stone",["pos"]={["x"]=-21.6834716796875,["y"]=-0.499359130859375,["z"]=-40.67340087890625},["land"]="S12",["sourceId"]=23729},["R23730"]={["kind"]="Stone",["pos"]={["x"]=-20.1761474609375,["y"]=-0.499603271484375,["z"]=-44.37543487548828},["land"]="S12",["sourceId"]=23730},["R23731"]={["kind"]="Pine Tree",["pos"]={["x"]=-17.924041748046875,["y"]=-0.5,["z"]=-29.15020751953125},["land"]="S10",["sourceId"]=23731},["R23732"]={["kind"]="Pine Tree",["pos"]={["x"]=-25.076141357421875,["y"]=-0.5,["z"]=-30.65020751953125},["land"]="S10",["sourceId"]=23732},["R23733"]={["kind"]="Pine Tree",["pos"]={["x"]=11.0760498046875,["y"]=-0.5,["z"]=-32.803466796875},["land"]="S6",["sourceId"]=23733},["R23734"]={["kind"]="Pine Tree",["pos"]={["x"]=8.1910400390625,["y"]=-0.5,["z"]=-30.145263671875},["land"]="S6",["sourceId"]=23734},["R23735"]={["kind"]="Pine Tree",["pos"]={["x"]=10.28131103515625,["y"]=-0.5,["z"]=-30.6119384765625},["land"]="S6",["sourceId"]=23735},["R23736"]={["kind"]="Pine Tree",["pos"]={["x"]=8.308258056640625,["y"]=-0.5,["z"]=-32.76483154296875},["land"]="S6",["sourceId"]=23736},["R23737"]={["kind"]="Pine Tree",["pos"]={["x"]=25.734161376953125,["y"]=-0.5,["z"]=-40.44903564453125},["land"]="S11",["sourceId"]=23737},["R23738"]={["kind"]="Pine Tree",["pos"]={["x"]=23.114593505859375,["y"]=-0.5,["z"]=-40.5662841796875},["land"]="S11",["sourceId"]=23738},["R23739"]={["kind"]="Pine Tree",["pos"]={["x"]=25.26751708984375,["y"]=-0.5,["z"]=-42.53936767578125},["land"]="S11",["sourceId"]=23739},["R23740"]={["kind"]="Pine Tree",["pos"]={["x"]=23.075958251953125,["y"]=-0.5,["z"]=-43.33404541015625},["land"]="S11",["sourceId"]=23740},["R23741"]={["kind"]="Pine Tree",["pos"]={["x"]=7.93829345703125,["y"]=-0.5,["z"]=-16.5045166015625},["land"]="S2",["sourceId"]=23741},["R23742"]={["kind"]="Stone",["pos"]={["x"]=-13.572479248046875,["y"]=-0.499786376953125,["z"]=-49.17413330078125},["land"]="S13",["sourceId"]=23742},["R23743"]={["kind"]="Stone",["pos"]={["x"]=-15.821014404296875,["y"]=-0.4994493800422788,["z"]=-47.84051513671875},["land"]="S13",["sourceId"]=23743},["R23744"]={["kind"]="Stone",["pos"]={["x"]=-13.99786376953125,["y"]=-0.4992644673166069,["z"]=-44.1851806640625},["land"]="S13",["sourceId"]=23744},["R23745"]={["kind"]="Stone",["pos"]={["x"]=-20.63800048828125,["y"]=-0.5001328680045845,["z"]=-53.36859130859375},["land"]="S16",["sourceId"]=23745},["R23746"]={["kind"]="Stone",["pos"]={["x"]=-19.087188720703125,["y"]=-0.49948944243533333,["z"]=-49.40875244140625},["land"]="S16",["sourceId"]=23746},["R23747"]={["kind"]="Stone",["pos"]={["x"]=-24.07611083984375,["y"]=-0.5,["z"]=-49.83416748046875},["land"]="S16",["sourceId"]=23747},["R23748"]={["kind"]="Stone",["pos"]={["x"]=-6.000762939453125,["y"]=-0.4994506637158338,["z"]=-47.0191650390625},["land"]="S13",["sourceId"]=23748},["R23749"]={["kind"]="Stone",["pos"]={["x"]=-7.30853271484375,["y"]=-0.499786376953125,["z"]=-44.7554931640625},["land"]="S13",["sourceId"]=23749},["R23750"]={["kind"]="Pine Tree",["pos"]={["x"]=21.580963134765625,["y"]=-0.500030517578125,["z"]=-30.47430419921875},["land"]="S9",["sourceId"]=23750},["R23751"]={["kind"]="Pine Tree",["pos"]={["x"]=24.058258056640625,["y"]=-0.500030517578125,["z"]=-29.2393798828125},["land"]="S9",["sourceId"]=23751},["R23752"]={["kind"]="Pine Tree",["pos"]={["x"]=22.3470458984375,["y"]=-0.500030517578125,["z"]=-27.65631103515625},["land"]="S9",["sourceId"]=23752},["R23753"]={["kind"]="Iron Ore",["pos"]={["x"]=-7.9202880859375,["y"]=1.4999923706054688,["z"]=-67.36334228515625},["land"]="S20",["sourceId"]=23753},["R23754"]={["kind"]="Stone",["pos"]={["x"]=3.6381072998046875,["y"]=-0.49959659576416016,["z"]=-49.534088134765625},["land"]="S8",["sourceId"]=23754},["R23755"]={["kind"]="Stone",["pos"]={["x"]=6.0760498046875,["y"]=-0.4998502731323242,["z"]=-53.018585205078125},["land"]="S8",["sourceId"]=23755},["R23756"]={["kind"]="Stone",["pos"]={["x"]=3.0760498046875,["y"]=-0.5000076293945312,["z"]=-52.67425537109375},["land"]="S8",["sourceId"]=23756},["R23757"]={["kind"]="Stone",["pos"]={["x"]=-7.887359619140625,["y"]=-0.4999980926513672,["z"]=-56.565277099609375},["land"]="S17",["sourceId"]=23757},["R23758"]={["kind"]="Stone",["pos"]={["x"]=-10.6214599609375,["y"]=-0.49976444244384766,["z"]=-55.283355712890625},["land"]="S17",["sourceId"]=23758},["R23759"]={["kind"]="Stone",["pos"]={["x"]=-8.067718505859375,["y"]=-0.4996356964111328,["z"]=-60.56227111816406},["land"]="S17",["sourceId"]=23759},["R23760"]={["kind"]="Iron Ore",["pos"]={["x"]=-8.4222412109375,["y"]=1.4999923706054688,["z"]=-71.1910400390625},["land"]="S20",["sourceId"]=23760},["R23761"]={["kind"]="Iron Ore",["pos"]={["x"]=-11.482498168945312,["y"]=1.4999923706054688,["z"]=-68.31210327148438},["land"]="S20",["sourceId"]=23761},["R23762"]={["kind"]="Iron Ore",["pos"]={["x"]=-14.101455688476562,["y"]=1.4999923706054688,["z"]=-75.23335266113281},["land"]="S20",["sourceId"]=23762},["R23763"]={["kind"]="Iron Ore",["pos"]={["x"]=-11.857925415039062,["y"]=1.4999923706054688,["z"]=-72.30827331542969},["land"]="S20",["sourceId"]=23763},["R23764"]={["kind"]="Iron Ore",["pos"]={["x"]=-9.9202880859375,["y"]=1.4999923706054688,["z"]=-75.64724731445312},["land"]="S20",["sourceId"]=23764},["R23765"]={["kind"]="Iron Ore",["pos"]={["x"]=-25.377273559570312,["y"]=1.50006103515625,["z"]=-66.57203674316406},["land"]="S19",["sourceId"]=23765},["R23766"]={["kind"]="Iron Ore",["pos"]={["x"]=-23.133743286132812,["y"]=1.50006103515625,["z"]=-63.64695739746094},["land"]="S19",["sourceId"]=23766},["R23767"]={["kind"]="Iron Ore",["pos"]={["x"]=-21.19610595703125,["y"]=1.50006103515625,["z"]=-66.98593139648438},["land"]="S19",["sourceId"]=23767},["R23768"]={["kind"]="Iron Ore",["pos"]={["x"]=-21.340194702148438,["y"]=1.499887466430664,["z"]=-73.90765380859375},["land"]="S21",["sourceId"]=23768},["R23769"]={["kind"]="Iron Ore",["pos"]={["x"]=-18.415115356445312,["y"]=1.499887466430664,["z"]=-76.15118408203125},["land"]="S21",["sourceId"]=23769},["R23770"]={["kind"]="Iron Ore",["pos"]={["x"]=-21.75408935546875,["y"]=1.499887466430664,["z"]=-78.08882141113281},["land"]="S21",["sourceId"]=23770},["R23771"]={["kind"]="Iron Ore",["pos"]={["x"]=4.127288818359375,["y"]=1.4999923706054688,["z"]=-74.64259338378906},["land"]="S23",["sourceId"]=23771},["R23772"]={["kind"]="Iron Ore",["pos"]={["x"]=5.0760498046875,["y"]=1.4999923706054688,["z"]=-78.20481872558594},["land"]="S23",["sourceId"]=23772},["R23773"]={["kind"]="Iron Ore",["pos"]={["x"]=1.24835205078125,["y"]=1.4999923706054688,["z"]=-77.70286560058594},["land"]="S23",["sourceId"]=23773},["R23774"]={["kind"]="Iron Ore",["pos"]={["x"]=11.714569091796875,["y"]=-0.49889278411865234,["z"]=-68.87344360351562},["land"]="S24",["sourceId"]=23774},["R23775"]={["kind"]="Iron Ore",["pos"]={["x"]=6.715576171875,["y"]=-0.49889278411865234,["z"]=-70.43208312988281},["land"]="S24",["sourceId"]=23775},["R23776"]={["kind"]="Iron Ore",["pos"]={["x"]=14.465164184570312,["y"]=-0.49889278411865234,["z"]=-74.322021484375},["land"]="S24",["sourceId"]=23776},["R23777"]={["kind"]="Iron Ore",["pos"]={["x"]=26.10809326171875,["y"]=1.4998359680175781,["z"]=-63.1168212890625},["land"]="S25",["sourceId"]=23777},["R23778"]={["kind"]="Iron Ore",["pos"]={["x"]=22.354843139648438,["y"]=1.4998359680175781,["z"]=-66.58651733398438},["land"]="S25",["sourceId"]=23778},["R23779"]={["kind"]="Iron Ore",["pos"]={["x"]=26.182540893554688,["y"]=1.4998359680175781,["z"]=-67.08847045898438},["land"]="S25",["sourceId"]=23779},["R23780"]={["kind"]="Crystal",["pos"]={["x"]=12.766143798828125,["y"]=-0.5000209808349609,["z"]=-86.21881103515625},["land"]="S28",["sourceId"]=23780},["R23781"]={["kind"]="Crystal",["pos"]={["x"]=11.8173828125,["y"]=-0.5000209808349609,["z"]=-82.65658569335938},["land"]="S28",["sourceId"]=23781},["R23782"]={["kind"]="Crystal",["pos"]={["x"]=8.938446044921875,["y"]=-0.5000209808349609,["z"]=-85.71685791015625},["land"]="S28",["sourceId"]=23782},["R23783"]={["kind"]="Crystal",["pos"]={["x"]=25.341354370117188,["y"]=-0.5001640319824219,["z"]=-76.2177734375},["land"]="S29",["sourceId"]=23783},["R23784"]={["kind"]="Crystal",["pos"]={["x"]=17.43414306640625,["y"]=-0.5001640319824219,["z"]=-79.27804565429688},["land"]="S29",["sourceId"]=23784},["R23785"]={["kind"]="Crystal",["pos"]={["x"]=26.290115356445312,["y"]=-0.5001640319824219,["z"]=-79.77999877929688},["land"]="S29",["sourceId"]=23785},["R23786"]={["kind"]="Crystal",["pos"]={["x"]=11.747146606445312,["y"]=-0.5000209808349609,["z"]=-97.53607177734375},["land"]="S31",["sourceId"]=23786},["R23787"]={["kind"]="Crystal",["pos"]={["x"]=9.878036499023438,["y"]=-0.5000209808349609,["z"]=-94.15826416015625},["land"]="S31",["sourceId"]=23787},["R23788"]={["kind"]="Crystal",["pos"]={["x"]=21.403152465820312,["y"]=-0.5000209808349609,["z"]=-89.43150329589844},["land"]="S30",["sourceId"]=23788},["R23789"]={["kind"]="Crystal",["pos"]={["x"]=17.669769287109375,["y"]=-0.5000209808349609,["z"]=-90.41386413574219},["land"]="S30",["sourceId"]=23789},["R23790"]={["kind"]="Crystal",["pos"]={["x"]=22.799957275390625,["y"]=-0.5000209808349609,["z"]=-94.40496826171875},["land"]="S30",["sourceId"]=23790},["R23791"]={["kind"]="Crystal",["pos"]={["x"]=24.714630126953125,["y"]=-0.5000209808349609,["z"]=-91.05276489257812},["land"]="S30",["sourceId"]=23791},["R23792"]={["kind"]="Crystal",["pos"]={["x"]=-3.200042724609375,["y"]=-0.5000209808349609,["z"]=-94.40496826171875},["land"]="S27",["sourceId"]=23792},["R23793"]={["kind"]="Crystal",["pos"]={["x"]=-1.285369873046875,["y"]=-0.5000209808349609,["z"]=-91.05276489257812},["land"]="S27",["sourceId"]=23793},["R23794"]={["kind"]="Crystal",["pos"]={["x"]=-25.129364013671875,["y"]=-0.5000209808349609,["z"]=-91.03013610839844},["land"]="S33",["sourceId"]=23794},["R23795"]={["kind"]="Crystal",["pos"]={["x"]=-23.36712646484375,["y"]=-0.5000209808349609,["z"]=-94.46493530273438},["land"]="S33",["sourceId"]=23795},["R23796"]={["kind"]="Crystal",["pos"]={["x"]=-12.345291137695312,["y"]=-0.5000209808349609,["z"]=-83.44282531738281},["land"]="S26",["sourceId"]=23796},["R23797"]={["kind"]="Crystal",["pos"]={["x"]=-10.583053588867188,["y"]=-0.5000209808349609,["z"]=-86.87762451171875},["land"]="S26",["sourceId"]=23797},["R23798"]={["kind"]="Crystal",["pos"]={["x"]=-10.322906494140625,["y"]=-0.5000209808349609,["z"]=-97.54638671875},["land"]="S32",["sourceId"]=23798},["R23799"]={["kind"]="Pine Tree",["pos"]={["x"]=2.78961181640625,["y"]=-0.5000076293945312,["z"]=-40.84516906738281},["land"]="S7",["sourceId"]=23799},["R23800"]={["kind"]="Pine Tree",["pos"]={["x"]=2.362457275390625,["y"]=-0.5000076293945312,["z"]=-36.945556640625},["land"]="S7",["sourceId"]=23800},["R23801"]={["kind"]="Pine Tree",["pos"]={["x"]=3.6310882568359375,["y"]=-0.5000076293945312,["z"]=-38.671142578125},["land"]="S7",["sourceId"]=23801},["R23802"]={["kind"]="Pine Tree",["pos"]={["x"]=0.7290496826171875,["y"]=-0.5000076293945312,["z"]=-38.99687194824219},["land"]="S7",["sourceId"]=23802},["R23803"]={["kind"]="Pine Tree",["pos"]={["x"]=17.173858642578125,["y"]=-0.5000076293945312,["z"]=-39.395416259765625},["land"]="S11",["sourceId"]=23803},["R23804"]={["kind"]="Pine Tree",["pos"]={["x"]=8.17242431640625,["y"]=-0.5000076293945312,["z"]=-41.739837646484375},["land"]="S14",["sourceId"]=23804},["R23805"]={["kind"]="Pine Tree",["pos"]={["x"]=15.49847412109375,["y"]=-0.5001354217529297,["z"]=-45.084136962890625},["land"]="S14",["sourceId"]=23805},["R23806"]={["kind"]="Pine Tree",["pos"]={["x"]=23.325958251953125,["y"]=-0.5000076293945312,["z"]=-53.772796630859375},["land"]="S15",["sourceId"]=23806},["R23807"]={["kind"]="Pine Tree",["pos"]={["x"]=22.575958251953125,["y"]=-0.5000076293945312,["z"]=-57.022796630859375},["land"]="S15",["sourceId"]=23807},["R23808"]={["kind"]="Pine Tree",["pos"]={["x"]=25.825958251953125,["y"]=-0.5001811981201172,["z"]=-54.022796630859375},["land"]="S15",["sourceId"]=23808},["R23809"]={["kind"]="Pine Tree",["pos"]={["x"]=9.487335205078125,["y"]=-0.5001850128173828,["z"]=-62.28108215332031},["land"]="S18",["sourceId"]=23809},["R23810"]={["kind"]="Pine Tree",["pos"]={["x"]=8.910675048828125,["y"]=-0.5000114440917969,["z"]=-59.835693359375},["land"]="S18",["sourceId"]=23810},["R23811"]={["kind"]="Pine Tree",["pos"]={["x"]=11.384140014648438,["y"]=-0.5000076293945312,["z"]=-24.87109375},["land"]="S2",["sourceId"]=23811},["R23812"]={["kind"]="Pine Tree",["pos"]={["x"]=12.66796875,["y"]=-0.5000076293945312,["z"]=-15.777244567871094},["land"]="S2",["sourceId"]=23812},["R23813"]={["kind"]="Pine Tree",["pos"]={["x"]=14.911285400390625,["y"]=-0.5000076293945312,["z"]=-24.655899047851562},["land"]="S2",["sourceId"]=23813},["R23814"]={["kind"]="Pine Tree",["pos"]={["x"]=10.132461547851562,["y"]=-0.5000076293945312,["z"]=-25.990074157714844},["land"]="S2",["sourceId"]=23814},["R23815"]={["kind"]="Pine Tree",["pos"]={["x"]=18.673858642578125,["y"]=-0.5002031326293945,["z"]=-23.211517333984375},["land"]="S9",["sourceId"]=23815},["R23816"]={["kind"]="Pine Tree",["pos"]={["x"]=19.295150756835938,["y"]=-0.5002031326293945,["z"]=-25.195472717285156},["land"]="S9",["sourceId"]=23816},["R23817"]={["kind"]="Pine Tree",["pos"]={["x"]=16.808853149414062,["y"]=-0.5002031326293945,["z"]=-29.290237426757812},["land"]="S9",["sourceId"]=23817},["R23818"]={["kind"]="Pine Tree",["pos"]={["x"]=25.494125366210938,["y"]=-0.5002031326293945,["z"]=-27.486251831054688},["land"]="S9",["sourceId"]=23818},["R23819"]={["kind"]="Pine Tree",["pos"]={["x"]=25.618637084960938,["y"]=-0.5002031326293945,["z"]=-30.77281951904297},["land"]="S9",["sourceId"]=23819},["R23820"]={["kind"]="Stone",["pos"]={["x"]=-27.064834594726562,["y"]=-0.499755859375,["z"]=-38.317222595214844},["land"]="S12",["sourceId"]=23820},["R23821"]={["kind"]="Pine Tree",["pos"]={["x"]=-13.223358154296875,["y"]=-0.5,["z"]=-18.24181365966797},["land"]="S4",["sourceId"]=23821},["R23822"]={["kind"]="Pine Tree",["pos"]={["x"]=-11.9140625,["y"]=-0.5,["z"]=-24.20238494873047},["land"]="S4",["sourceId"]=23822},["R23823"]={["kind"]="Stone",["pos"]={["x"]=-14.423110961914062,["y"]=-0.5000228881835938,["z"]=-61.48387145996094},["land"]="S17",["sourceId"]=23823},["R23824"]={["kind"]="Stone",["pos"]={["x"]=-14.887496948242188,["y"]=-0.4995520976772241,["z"]=-58.32777404785156},["land"]="S17",["sourceId"]=23824},["R23825"]={["kind"]="Stone",["pos"]={["x"]=-11.469085693359375,["y"]=-0.4998960494995117,["z"]=-60.8575439453125},["land"]="S17",["sourceId"]=23825}}
-- Explicit reconstruction choices, NOT values recovered from the original server.
-- Elapsed time is informational. There is no score/time-limit victory.
Data.RoundSeconds = 0
Data.ResultSeconds = 12
Data.MaxTrainingQueue = 12
Data.MaxCraftQueue = 20
Data.MaxBuildSeconds = 90
Data.MaxResearchSeconds = 90
Data.WorkerSpeed = 5.2
Data.ChopInterval = 0.74
Data.WorkerCarry = 10
Data.ResourceHP = 10
-- HP from native Resource model attributes; bridge price from Balancer.
Data.ResourceHealth = {["Pine Tree"]=5,Stone=5,["Iron Ore"]=9,Crystal=12}
Data.BridgeCost = {Log=250,Stone=100}
Data.RegrowSeconds = 25
Data.CampRearmSeconds = 20
Data.GoldRateMultiplier = 12
-- S30 is a resource camp, never a victory trigger.
Data.CaptureSeconds = 10
Data.CaptureRadius = 6.5
Data.MaxNavStepHeight = 8
Data.NeutralGuardTiers = {
 Small={Barbarian=4,Archer=2},
 Medium={Barbarian=5,Archer=2,Giant=1},
 Large={Barbarian=6,Archer=3,Giant=1,Wizard=1}
}
Data.ResourceOrder = {"Log","Stone","Gold","Plank","Iron Ore","Iron Bar","Crystal","Trophy"}
Data.ResourceNames = {Log="Wood",Stone="Stone",Gold="Gold",Plank="Planks",["Iron Ore"]="Iron Ore",["Iron Bar"]="Iron Bars",Crystal="Crystals",Trophy="Trophies"}
Data.WorkerResources = {LumberHut="Log",MinerHut="Stone",OreMinerHut="Iron Ore",CrystalMinerHut="Crystal"}
Data.ResourceKinds = {["Pine Tree"]="Log",Stone="Stone",["Iron Ore"]="Iron Ore",Crystal="Crystal"}
Data.BuildingNames = {Townhall="Town Hall",LumberHut="Lumber Hut",MinerHut="Miner Hut",OreMinerHut="Ore Mine",CrystalMinerHut="Crystal Mine",BuilderHut="Builder Hut",Barracks="Barracks",Campsite="Campsite",GoldMine="Gold Mine",Sawmill="Sawmill",Foundry="Foundry",TrainingCamp="Training Camp"}
Data.ResourceHelp = {
 Log="Wood: click a Lumber Hut to collect the wood delivered by your lumberjacks.",
 Stone="Stone: clear the S12 camp, then click your Miner Hut to collect stone.",
 Gold="Gold: clear camps, collect from Gold Mines, or capture central island bases.",
 Plank="Planks: click your Sawmill to craft planks from wood.",
 ["Iron Ore"]="Iron Ore: unlock ore deposits and collect from your Ore Mine.",
 ["Iron Bar"]="Iron Bars: use a Foundry to smelt iron ore.",
 Crystal="Crystals: unlock crystal deposits and collect from your Crystal Mine.",
 Trophy="Trophies: earned by defeating enemy troops. Trophies do not decide victory."
}
return Data