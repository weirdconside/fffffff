-- Adapted source ReplicatedStorage.Directory.Assets.Personalities.luau; original motion and personality constants retained.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local function LotteryCustom(random, entries)
 local total=0; for _, entry in ipairs(entries) do total+=entry[2] end
 local roll=random:NextNumber(0,total); for _,entry in ipairs(entries) do roll-=entry[2]; if roll<=0 then return entry[1] end end
 return entries[#entries][1]
end


local function DeepFreezeUnsafe(value)
 for _, item in pairs(value) do if type(item)=="table" and not table.isfrozen(item) then DeepFreezeUnsafe(item) end end
 return table.freeze(value)
end
local v4 = table.freeze({
	Normal = "Normal",
	Lazy = "Lazy",
	Loyal = "Loyal",
	Energetic = "Energetic",
	InvertedModel = "InvertedModel",
	Shy = "Shy",
	Scared = "Scared",
	ExtremelyEnergetic = "ExtremelyEnergetic",
	UltraLoyal = "UltraLoyal",
	JumpCrazy = "JumpCrazy"
})
local t1 = {
	RollWeight = 12.0,
	_id = v4.Energetic,
	Movement = {
		WalkSpeedMin = 9.0,
		WalkSpeedMax = 20.0,
		IdleSecondsMin = 0.1,
		IdleSecondsMax = 0.75,
		NearOwnerPreference = 0.2,
		IsolationPreference = 0.0,
		CurvedWanderChance = 0.62,
		BurstChance = 0.42,
		FollowOwnerInPen = false,
		AmbientJumpRatePerSecond = 0.0,
		AmbientSpinJumpChance = 0.0
	},
	Greeting = {
		Chance = 1.0,
		FirstPlacementChance = 1.0,
		FirstPlacementNormalChance = 0.0,
		FirstPlacementNormalJumpCount = 4.0,
		ReturnOrbitChance = 0.6,
		ReturnNormalJumpCount = 3.0,
		RandomOrbitChance = 0.2,
		RandomOrbitIntervalSeconds = 45.0,
		DurationSeconds = 6.0,
		JumpChancePerSecond = 0.85,
		SpinJumpChance = 0.3,
		Texts = {
			"😊",
			"😄",
			"🥰"
		}
	},
	Affection = {
		Enabled = true,
		Chance = 0.125,
		IntervalSeconds = 5.0,
		DurationSeconds = 4.5,
		JumpCount = 5.0,
		Texts = {
			"😆",
			"😄",
			"😁",
			"😃",
			"🤪",
			"😝",
			"😜",
			"😋",
			"😹",
			"🙀",
			"😎"
		}
	}
}
local Greeting = t1.Greeting
local t2 = {
	Chance = Greeting.Chance,
	FirstPlacementChance = Greeting.FirstPlacementChance,
	FirstPlacementNormalChance = Greeting.FirstPlacementNormalChance,
	FirstPlacementNormalJumpCount = Greeting.FirstPlacementNormalJumpCount,
	ReturnOrbitChance = Greeting.ReturnOrbitChance,
	ReturnNormalJumpCount = Greeting.ReturnNormalJumpCount,
	RandomOrbitChance = Greeting.RandomOrbitChance,
	RandomOrbitIntervalSeconds = Greeting.RandomOrbitIntervalSeconds,
	DurationSeconds = Greeting.DurationSeconds,
	JumpChancePerSecond = Greeting.JumpChancePerSecond,
	SpinJumpChance = Greeting.SpinJumpChance,
	Texts = {
		"//ERRsORijwoR//",
		"0x?#!@NLL",
		"01011010???",
		"▓▒░???░▒▓",
		"M4M4.EXE???",
		"##!%$@//",
		"<???:'aWsFE>",
		"1010_=249_0101",
		"??//V//#"
	}
}
local t3 = {
	RollWeight = 1.5,
	_id = v4.InvertedModel,
	Movement = t1.Movement,
	Greeting = t2,
	Affection = t1.Affection
}
local v9 = DeepFreezeUnsafe({
	Normal = {
		RollWeight = 37.0,
		_id = v4.Normal,
		Movement = {
			WalkSpeedMin = 6.5,
			WalkSpeedMax = 12.0,
			IdleSecondsMin = 1.2,
			IdleSecondsMax = 3.2,
			NearOwnerPreference = 0.14,
			IsolationPreference = 0.0,
			CurvedWanderChance = 0.16,
			BurstChance = 0.035,
			FollowOwnerInPen = false,
			AmbientJumpRatePerSecond = 0.0,
			AmbientSpinJumpChance = 0.0
		},
		Greeting = {
			Chance = 1.0,
			FirstPlacementChance = 0.0,
			FirstPlacementNormalChance = 1.0,
			FirstPlacementNormalJumpCount = 3.0,
			ReturnOrbitChance = 0.0,
			ReturnNormalJumpCount = 2.0,
			RandomOrbitChance = 0.0,
			RandomOrbitIntervalSeconds = 45.0,
			DurationSeconds = 6.0,
			JumpChancePerSecond = 0.8,
			SpinJumpChance = 0.08,
			Texts = {
				"😊",
				"😄",
				"🥰"
			}
		},
		Affection = {
			Enabled = true,
			Chance = 0.16666666666666666,
			IntervalSeconds = 5.0,
			DurationSeconds = 4.0,
			JumpCount = 2.0,
			Texts = {
				"😊",
				"😄",
				"🙂",
				"☺\239\184\143",
				"🥰",
				"😃",
				"😁",
				"🤗"
			}
		}
	},
	Lazy = {
		RollWeight = 15.0,
		_id = v4.Lazy,
		Movement = {
			WalkSpeedMin = 2.5,
			WalkSpeedMax = 3.75,
			IdleSecondsMin = 6.0,
			IdleSecondsMax = 15.0,
			NearOwnerPreference = 0.025,
			IsolationPreference = 0.08,
			CurvedWanderChance = 0.025,
			BurstChance = 0.0,
			FollowOwnerInPen = false,
			AmbientJumpRatePerSecond = 0.0,
			AmbientSpinJumpChance = 0.0
		},
		Greeting = {
			Chance = 0.0,
			FirstPlacementChance = 0.0,
			FirstPlacementNormalChance = 0.0,
			FirstPlacementNormalJumpCount = 0.0,
			ReturnOrbitChance = 0.0,
			ReturnNormalJumpCount = 1.0,
			RandomOrbitChance = 0.0,
			RandomOrbitIntervalSeconds = 60.0,
			DurationSeconds = 3.5,
			JumpChancePerSecond = 0.08,
			SpinJumpChance = 0.0,
			Texts = {
				"😊",
				"😄",
				"🥰"
			}
		},
		Affection = {
			Enabled = false,
			Chance = 0.0,
			IntervalSeconds = 80.0,
			DurationSeconds = 0.0,
			JumpCount = 0.0,
			Texts = {
				"😴",
				"🥱",
				"😪",
				"😌",
				"😐",
				"😑",
				"😶",
				"🙃"
			}
		}
	},
	Loyal = {
		RollWeight = 10.0,
		_id = v4.Loyal,
		Movement = {
			WalkSpeedMin = 7.5,
			WalkSpeedMax = 10.0,
			IdleSecondsMin = 0.35,
			IdleSecondsMax = 1.25,
			NearOwnerPreference = 0.9,
			IsolationPreference = 0.0,
			CurvedWanderChance = 0.08,
			BurstChance = 0.055,
			FollowOwnerInPen = true,
			AmbientJumpRatePerSecond = 0.0,
			AmbientSpinJumpChance = 0.0
		},
		Greeting = {
			Chance = 1.0,
			FirstPlacementChance = 1.0,
			FirstPlacementNormalChance = 0.0,
			FirstPlacementNormalJumpCount = 3.0,
			ReturnOrbitChance = 0.45,
			ReturnNormalJumpCount = 2.0,
			RandomOrbitChance = 0.08,
			RandomOrbitIntervalSeconds = 45.0,
			DurationSeconds = 6.5,
			JumpChancePerSecond = 0.55,
			SpinJumpChance = 0.06,
			Texts = { "Mama" }
		},
		Affection = {
			Enabled = true,
			Chance = 0.002976190476190476,
			IntervalSeconds = 5.0,
			DurationSeconds = 5.0,
			JumpCount = 2.0,
			Texts = {
				"🥰",
				"😍",
				"😊",
				"☺\239\184\143",
				"🤗",
				"😚"
			}
		}
	},
	Energetic = t1,
	InvertedModel = t3,
	Shy = {
		RollWeight = 10.0,
		_id = v4.Shy,
		Movement = {
			WalkSpeedMin = 3.0,
			WalkSpeedMax = 5.0,
			IdleSecondsMin = 5.5,
			IdleSecondsMax = 14.0,
			NearOwnerPreference = 0.0,
			IsolationPreference = 0.95,
			CurvedWanderChance = 0.035,
			BurstChance = 0.0,
			FollowOwnerInPen = false,
			AmbientJumpRatePerSecond = 0.0,
			AmbientSpinJumpChance = 0.0,
			Retreat = {
				TriggerDistance = 22.0,
				Chance = 0.85,
				MaxTravelDistance = 16.0
			}
		},
		Greeting = {
			Chance = 0.0,
			FirstPlacementChance = 0.0,
			FirstPlacementBubbleChance = 0.0,
			FirstPlacementNormalChance = 0.0,
			FirstPlacementNormalJumpCount = 0.0,
			ReturnOrbitChance = 0.0,
			ReturnNormalJumpCount = 0.0,
			RandomOrbitChance = 0.0,
			RandomOrbitIntervalSeconds = 30.0,
			DurationSeconds = 0.0,
			JumpChancePerSecond = 0.0,
			SpinJumpChance = 0.0,
			Texts = { "😊" }
		},
		Affection = {
			Enabled = false,
			Chance = 0.0,
			IntervalSeconds = 50.0,
			DurationSeconds = 0.0,
			JumpCount = 0.0,
			Texts = {
				"😊",
				"😄",
				"🥰"
			}
		}
	},
	Scared = {
		RollWeight = 5.0,
		_id = v4.Scared,
		Movement = {
			WalkSpeedMin = 20.0,
			WalkSpeedMax = 40.0,
			IdleSecondsMin = 0.8,
			IdleSecondsMax = 4.0,
			NearOwnerPreference = 0.0,
			IsolationPreference = 1.0,
			CurvedWanderChance = 0.03,
			BurstChance = 0.0,
			FollowOwnerInPen = false,
			AmbientJumpRatePerSecond = 0.0,
			AmbientSpinJumpChance = 0.0,
			Retreat = {
				TriggerDistance = 20.0,
				Chance = 1.0
			},
			IdleTremble = {
				Amplitude = 1.5,
				CyclesPerSecond = 16.0
			}
		},
		Greeting = {
			Chance = 0.0,
			FirstPlacementChance = 0.0,
			FirstPlacementBubbleChance = 1.0,
			FirstPlacementNormalChance = 0.0,
			FirstPlacementNormalJumpCount = 0.0,
			ReturnOrbitChance = 0.0,
			ReturnNormalJumpCount = 0.0,
			RandomOrbitChance = 0.0,
			RandomOrbitIntervalSeconds = 30.0,
			DurationSeconds = 0.0,
			JumpChancePerSecond = 0.0,
			SpinJumpChance = 0.0,
			Texts = { "Where is MAMA 😰?" }
		},
		Affection = {
			Enabled = false,
			Chance = 0.0,
			IntervalSeconds = 50.0,
			DurationSeconds = 0.0,
			JumpCount = 0.0,
			Texts = {
				"😨",
				"😰"
			}
		}
	},
	ExtremelyEnergetic = {
		RollWeight = 3.5,
		_id = v4.ExtremelyEnergetic,
		Movement = {
			WalkSpeedMin = 30.0,
			WalkSpeedMax = 70.0,
			IdleSecondsMin = 0.05,
			IdleSecondsMax = 0.2,
			NearOwnerPreference = 0.2,
			IsolationPreference = 0.0,
			CurvedWanderChance = 0.8,
			BurstChance = 0.7,
			FollowOwnerInPen = false,
			AmbientJumpRatePerSecond = 3.5,
			AmbientSpinJumpChance = 0.35
		},
		Greeting = {
			Chance = 1.0,
			FirstPlacementChance = 1.0,
			FirstPlacementNormalChance = 0.0,
			FirstPlacementNormalJumpCount = 5.0,
			ReturnOrbitChance = 0.75,
			ReturnNormalJumpCount = 5.0,
			RandomOrbitChance = 0.35,
			RandomOrbitIntervalSeconds = 30.0,
			DurationSeconds = 6.0,
			JumpChancePerSecond = 1.8,
			SpinJumpChance = 0.4,
			Texts = {
				"🤩",
				"🤪"
			}
		},
		Affection = {
			Enabled = true,
			Chance = 0.1,
			IntervalSeconds = 5.0,
			DurationSeconds = 4.5,
			JumpCount = 7.0,
			Texts = {
				"🤩",
				"😆",
				"🤪"
			}
		}
	},
	UltraLoyal = {
		RollWeight = 2.5,
		_id = v4.UltraLoyal,
		Movement = {
			WalkSpeedMin = 10.0,
			WalkSpeedMax = 16.0,
			IdleSecondsMin = 0.1,
			IdleSecondsMax = 0.5,
			NearOwnerPreference = 0.98,
			IsolationPreference = 0.0,
			CurvedWanderChance = 0.12,
			BurstChance = 0.1,
			FollowOwnerInPen = true,
			AmbientJumpRatePerSecond = 0.35,
			AmbientSpinJumpChance = 0.1
		},
		Greeting = {
			Chance = 1.0,
			FirstPlacementChance = 1.0,
			FirstPlacementNormalChance = 0.0,
			FirstPlacementNormalJumpCount = 4.0,
			ReturnOrbitChance = 0.9,
			ReturnNormalJumpCount = 3.0,
			RandomOrbitChance = 0.9,
			RandomOrbitIntervalSeconds = 5.0,
			DurationSeconds = 6.5,
			JumpChancePerSecond = 0.8,
			SpinJumpChance = 0.1,
			Texts = {
				"Mama 🤗",
				"Mama 🥰"
			}
		},
		Affection = {
			Enabled = true,
			Chance = 0.15151515151515152,
			IntervalSeconds = 5.0,
			DurationSeconds = 5.0,
			JumpCount = 3.0,
			Texts = {
				"🥰",
				"🤗"
			}
		}
	},
	JumpCrazy = {
		RollWeight = 3.5,
		_id = v4.JumpCrazy,
		Movement = {
			WalkSpeedMin = 10.0,
			WalkSpeedMax = 18.0,
			IdleSecondsMin = 0.05,
			IdleSecondsMax = 0.3,
			NearOwnerPreference = 0.2,
			IsolationPreference = 0.0,
			CurvedWanderChance = 0.25,
			BurstChance = 0.1,
			FollowOwnerInPen = false,
			AmbientJumpRatePerSecond = 12.0,
			AmbientSpinJumpChance = 0.5
		},
		Greeting = {
			Chance = 1.0,
			FirstPlacementChance = 0.0,
			FirstPlacementNormalChance = 1.0,
			FirstPlacementNormalJumpCount = 8.0,
			ReturnOrbitChance = 0.0,
			ReturnNormalJumpCount = 7.0,
			RandomOrbitChance = 0.0,
			RandomOrbitIntervalSeconds = 30.0,
			DurationSeconds = 6.0,
			JumpChancePerSecond = 2.0,
			SpinJumpChance = 0.5,
			Texts = {
				"😆",
				"😄",
				"😁",
				"😃",
				"🤪",
				"😝",
				"😜",
				"😋",
				"😹",
				"🙀",
				"😎"
			}
		},
		Affection = {
			Enabled = true,
			Chance = 0.1,
			IntervalSeconds = 5.0,
			DurationSeconds = 4.0,
			JumpCount = 8.0,
			Texts = {
				"😆",
				"😄",
				"😁",
				"😃",
				"🤪",
				"😝",
				"😜",
				"😋",
				"😹",
				"🙀",
				"😎"
			}
		}
	}
})
local v10 = table.freeze({
	{
		Personality = v4.Normal,
		Weight = v9[v4.Normal].RollWeight
	},
	{
		Personality = v4.Lazy,
		Weight = v9[v4.Lazy].RollWeight
	},
	{
		Personality = v4.Loyal,
		Weight = v9[v4.Loyal].RollWeight
	},
	{
		Personality = v4.Energetic,
		Weight = v9[v4.Energetic].RollWeight
	},
	{
		Personality = v4.InvertedModel,
		Weight = v9[v4.InvertedModel].RollWeight
	},
	{
		Personality = v4.Shy,
		Weight = v9[v4.Shy].RollWeight
	},
	{
		Personality = v4.Scared,
		Weight = v9[v4.Scared].RollWeight
	},
	{
		Personality = v4.ExtremelyEnergetic,
		Weight = v9[v4.ExtremelyEnergetic].RollWeight
	},
	{
		Personality = v4.UltraLoyal,
		Weight = v9[v4.UltraLoyal].RollWeight
	},
	{
		Personality = v4.JumpCrazy,
		Weight = v9[v4.JumpCrazy].RollWeight
	}
})
local v11 = table.freeze({
	{
		v4.Normal,
		v9[v4.Normal].RollWeight
	},
	{
		v4.Lazy,
		v9[v4.Lazy].RollWeight
	},
	{
		v4.Loyal,
		v9[v4.Loyal].RollWeight
	},
	{
		v4.Energetic,
		v9[v4.Energetic].RollWeight
	},
	{
		v4.InvertedModel,
		v9[v4.InvertedModel].RollWeight
	},
	{
		v4.Shy,
		v9[v4.Shy].RollWeight
	},
	{
		v4.Scared,
		v9[v4.Scared].RollWeight
	},
	{
		v4.ExtremelyEnergetic,
		v9[v4.ExtremelyEnergetic].RollWeight
	},
	{
		v4.UltraLoyal,
		v9[v4.UltraLoyal].RollWeight
	},
	{
		v4.JumpCrazy,
		v9[v4.JumpCrazy].RollWeight
	}
})
local t4 = {
	Personalities = v4,
	Configs = v9,
	RollTable = v10,
	IsPersonality = function(s1: string) -- line: 489
		return v9[s1] ~= nil
	end,
	GetConfig = function(p1) -- line: 493
		local v15 = v9[p1]

		assert(v15 ~= nil, `Unknown asset personality "{ p1 }"`)

		return v15
	end
}

function t4.Roll(p2) -- line: 499
	local v17 = LotteryCustom(p2, v11)

	assert(typeof(v17) == "string" and t4.IsPersonality(v17), "Asset personality roll failed")

	return v17
end
function t4.CreateNewItemData(p3, p4, p5) -- line: 505
	local v21 = table.clone(p3)

	v21.Mutations = table.clone(p3.Mutations)

	if p5 == nil then
		v21.Personality = t4.Roll(p4)
	else
		assert(t4.IsPersonality(p5), "Invalid asset personality override")
		v21.Personality = p5
	end

	v21.HasBeenFirstPlaced = false

	return v21
end
function t4.ResetFirstPlacementForTransfer(p6) -- line: 522
	local v23 = table.clone(p6)

	v23.Mutations = table.clone(p6.Mutations)
	v23.HasBeenFirstPlaced = false

	return v23
end

return t4

