--!optimize 2
--!native
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(game.ServerScriptService.jecs:Clone())
local chrono = require(game.ServerScriptService["chronecs 4"]:Clone())
local ecs = jecs.world()
local ccs = chrono.new()

local comps = 20

local D = {}
local E = {}
for i = 1, comps do
	D[i] = ecs:component()
	E[i] = ccs:component()
end

local function flip()
	return math.random() >= 0.3
end

local N = 2 ^ 16 - 2
local actual = 0

for i = 1, N do
	local entity = ecs:entity()
	local m = ccs:entity()

	for c = 1, comps do
		if flip() then
			if c % 2 == 0 then
				actual += 1
			end
			ecs:set(entity, D[c], true)
			ccs:set(m, E[c], true)
		end
	end
end

local c = 0
local query_comps_d = {}
local query_comps_e = {}
for i = 1, comps do
	if i % 2 == 0 then
		table.insert(query_comps_d, D[i])
		table.insert(query_comps_e, E[i])
	end
end

return {
	ParameterGenerator = function()
		return
	end,
	Functions = {
		chrono = function(Profiler)
			c += 1
			local iteration_count = 0
			local first = nil
			for entityId, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10 in ccs:view(unpack(query_comps_e)) do
				iteration_count = iteration_count + 1
				first = c1
			end
			if c == 1000 then
				print(iteration_count, actual, first)
			end
		end,

		Jecs = function(Profiler)
			local it = 0
			local first
			for entityId, firstComponent in ecs:query(unpack(query_comps_d)) do
				it += 1
				first = firstComponent
			end
			if c == 1000 then
				print(it, actual, first)
			end
		end,
	},
}
