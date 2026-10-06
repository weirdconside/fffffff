--!strict
-- Deterministic Park-Miller PRNG. Pure arithmetic (exact in doubles), so the same
-- seed gives the same sequence on the server, every client, and offline tools.
local Rng = {}
Rng.__index = Rng

export type Rng = typeof(setmetatable({} :: {s: number}, Rng))

function Rng.new(seed: number): Rng
	local s = math.floor(math.abs(seed)) % 2147483646 + 1
	local self = setmetatable({s = s}, Rng)
	-- warm up so nearby seeds diverge
	for _ = 1, 3 do self:Next() end
	return self
end

function Rng.Next(self: Rng): number
	self.s = (self.s * 48271) % 2147483647
	return (self.s - 1) / 2147483646
end

function Rng.Range(self: Rng, a: number, b: number): number
	return a + (b - a) * self:Next()
end

function Rng.Int(self: Rng, a: number, b: number): number
	return math.min(b, a + math.floor(self:Next() * (b - a + 1)))
end

function Rng.Pick<T>(self: Rng, list: {T}): T
	return list[self:Int(1, #list)]
end

-- Weighted pick: entries have a numeric field `weightKey`.
function Rng.Weighted(self: Rng, list: {any}, weightKey: string): any
	local total = 0
	for _, entry in ipairs(list) do total += math.max(0, entry[weightKey] or 0) end
	if total <= 0 then return list[1] end
	local roll = self:Next() * total
	for _, entry in ipairs(list) do
		roll -= math.max(0, entry[weightKey] or 0)
		if roll <= 0 then return entry end
	end
	return list[#list]
end

return Rng
