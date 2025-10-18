--[[
This file is for use by Benchmarker (https://boatbomber.itch.io/benchmarker)

|WARNING| THIS RUNS IN YOUR REAL ENVIRONMENT. |WARNING|
--]]

local chronecs = require(game.ServerScriptService["chronecs 3"])
local jecs = require(game.ServerScriptService.jecs)

local count = 20
local query_creation = 10
local query_iterations = 10
local entities = 1000

return {
	ParameterGenerator = function()
		return
	end,

	BeforeAll = function() end,
	AfterAll = function() end,
	BeforeEach = function() end,
	AfterEach = function() end,

	Functions = {
		["Chronecs Query Creation"] = function(Profiler)
			Profiler.Begin("Setup")
			local world = chronecs.new()
			local pos = world:component()
			local vel = world:component()
			local v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, v16, v17, v18 =
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component()

			for i = 1, entities do
				local e = world:entity()
				world:add(e, pos, vel, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10)
				world:set(e, pos, { 0, 0, 0 })
				world:set(e, vel, { 0, 0, 0 })
				world:set(e, v1, { 0, 0, 0 })
				world:set(e, v2, { 0, 0, 0 })
				world:set(e, v3, { 0, 0, 0 })
				world:set(e, v4, { 0, 0, 0 })
				world:set(e, v5, { 0, 0, 0 })
				world:set(e, v6, { 0, 0, 0 })
				world:set(e, v7, { 0, 0, 0 })
				world:set(e, v8, { 0, 0, 0 })
				world:set(e, v9, { 0, 0, 0 })
				world:set(e, v10, { 0, 0, 0 })
				world:set(e, v11, { 0, 0, 0 })
				world:set(e, v12, { 0, 0, 0 })
				world:set(e, v13, { 0, 0, 0 })
				world:set(e, v14, { 0, 0, 0 })
				world:set(e, v15, { 0, 0, 0 })
				world:set(e, v16, { 0, 0, 0 })
				world:set(e, v17, { 0, 0, 0 })
				world:set(e, v18, { 0, 0, 0 })
			end
			Profiler.End()

			Profiler.Begin("Creation")
			for i = 1, query_creation do
				local c = 0
				for id in
					world:view(
						pos,
						vel,
						v1,
						v2,
						v3,
						v4,
						v5,
						v6,
						v7,
						v8,
						v9,
						v10,
						v11,
						v12,
						v13,
						v14,
						v15,
						v16,
						v17,
						v18
					)
				do
					c += 1
				end
			end
			Profiler.End()
		end,

		["Jecs Query Creation"] = function(Profiler)
			Profiler.Begin("Setup")
			local world = jecs.World.new()
			local pos = world:component()
			local vel = world:component()
			local v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, v16, v17, v18 =
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component()

			for i = 1, entities do
				local e = world:entity()
				world:set(e, pos, { 0, 0, 0 })
				world:set(e, vel, { 0, 0, 0 })
				world:set(e, v1, { 0, 0, 0 })
				world:set(e, v2, { 0, 0, 0 })
				world:set(e, v3, { 0, 0, 0 })
				world:set(e, v4, { 0, 0, 0 })
				world:set(e, v5, { 0, 0, 0 })
				world:set(e, v6, { 0, 0, 0 })
				world:set(e, v7, { 0, 0, 0 })
				world:set(e, v8, { 0, 0, 0 })
				world:set(e, v9, { 0, 0, 0 })
				world:set(e, v10, { 0, 0, 0 })
				world:set(e, v11, { 0, 0, 0 })
				world:set(e, v12, { 0, 0, 0 })
				world:set(e, v13, { 0, 0, 0 })
				world:set(e, v14, { 0, 0, 0 })
				world:set(e, v15, { 0, 0, 0 })
				world:set(e, v16, { 0, 0, 0 })
				world:set(e, v17, { 0, 0, 0 })
				world:set(e, v18, { 0, 0, 0 })
			end
			Profiler.End()

			Profiler.Begin("Creation")
			for i = 1, query_creation do
				local c = 0
				for id in
					world:query(
						pos,
						vel,
						v1,
						v2,
						v3,
						v4,
						v5,
						v6,
						v7,
						v8,
						v9,
						v10,
						v11,
						v12,
						v13,
						v14,
						v15,
						v16,
						v17,
						v18
					)
				do
					c += 1
				end
			end
			Profiler.End()
		end,

		["Chronecs Iteration 20 Components"] = function(Profiler)
			Profiler.Begin("Setup")
			local world = chronecs.new()
			local pos = world:component()
			local vel = world:component()
			local v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, v16, v17, v18 =
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component()

			for i = 1, entities do
				local e = world:entity()
				world:add(e, pos, vel)
				world:set(e, pos, { x = i, y = i, z = i })
				world:set(e, vel, { x = 1, y = 1, z = 1 })
				world:set(e, v1, { 0, 0, 0 })
				world:set(e, v2, { 0, 0, 0 })
				world:set(e, v3, { 0, 0, 0 })
				world:set(e, v4, { 0, 0, 0 })
				world:set(e, v5, { 0, 0, 0 })
				world:set(e, v6, { 0, 0, 0 })
				world:set(e, v7, { 0, 0, 0 })
				world:set(e, v8, { 0, 0, 0 })
				world:set(e, v9, { 0, 0, 0 })
				world:set(e, v10, { 0, 0, 0 })
				world:set(e, v11, { 0, 0, 0 })
				world:set(e, v12, { 0, 0, 0 })
				world:set(e, v13, { 0, 0, 0 })
				world:set(e, v14, { 0, 0, 0 })
				world:set(e, v15, { 0, 0, 0 })
				world:set(e, v16, { 0, 0, 0 })
				world:set(e, v17, { 0, 0, 0 })
				world:set(e, v18, { 0, 0, 0 })
			end
			Profiler.End()

			Profiler.Begin("Iteration")
			for i = 1, query_iterations do
				for id, p, v in world:view(pos, vel) do
					p.x += v.x
					p.y += v.y
					p.z += v.z
				end
			end
			Profiler.End()
		end,

		["Jecs Iteration 20 Components"] = function(Profiler)
			Profiler.Begin("Setup")
			local world = jecs.World.new()
			local pos = world:component()
			local vel = world:component()
			local v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, v16, v17, v18 =
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component(),
				world:component()

			for i = 1, entities do
				local e = world:entity()
				world:add(e, pos, vel)
				world:set(e, pos, { x = i, y = i, z = i })
				world:set(e, vel, { x = 1, y = 1, z = 1 })
				world:set(e, v1, { 0, 0, 0 })
				world:set(e, v2, { 0, 0, 0 })
				world:set(e, v3, { 0, 0, 0 })
				world:set(e, v4, { 0, 0, 0 })
				world:set(e, v5, { 0, 0, 0 })
				world:set(e, v6, { 0, 0, 0 })
				world:set(e, v7, { 0, 0, 0 })
				world:set(e, v8, { 0, 0, 0 })
				world:set(e, v9, { 0, 0, 0 })
				world:set(e, v10, { 0, 0, 0 })
				world:set(e, v11, { 0, 0, 0 })
				world:set(e, v12, { 0, 0, 0 })
				world:set(e, v13, { 0, 0, 0 })
				world:set(e, v14, { 0, 0, 0 })
				world:set(e, v15, { 0, 0, 0 })
				world:set(e, v16, { 0, 0, 0 })
				world:set(e, v17, { 0, 0, 0 })
				world:set(e, v18, { 0, 0, 0 })
			end
			Profiler.End()

			Profiler.Begin("Iteration")
			for i = 1, query_iterations do
				for id, p, v in world:query(pos, vel) do
					p.x += v.x
					p.y += v.y
					p.z += v.z
				end
			end
			Profiler.End()
		end,

		["Chronecs 1k Entity Creation"] = function(Profiler)
			local world = chronecs.new()
			local pos = world:component()

			Profiler.Begin("Creation")
			for i = 1, entities do
				local e = world:entity()
				world:add(e, pos)
				world:set(e, pos, { x = i, y = i, z = i })
			end

			Profiler.End()
		end,

		["Jecs 1k Entity Creation"] = function(Profiler)
			local world = jecs.World.new()
			local pos = world:component()

			Profiler.Begin("Creation")
			for i = 1, entities do
				local e = world:entity()
				world:add(e, pos)
				world:set(e, pos, { x = i, y = i, z = i })
			end

			Profiler.End()
		end,

		["Chronecs Component Add"] = function(Profiler)
			Profiler.Begin("Setup")
			local world = chronecs.new()
			local pos = world:component()
			local vel = world:component()
			local ids = {}

			for i = 1, entities do
				local e = world:entity()
				world:add(e, pos)
				world:set(e, pos, { x = i, y = i, z = i })
				ids[i] = e
			end
			Profiler.End()

			Profiler.Begin("Adding")
			for i = 1, entities do
				world:add(ids[i], vel)
				world:set(ids[i], vel, { x = 1, y = 1, z = 1 })
			end
			Profiler.End()
		end,

		["Jecs Component Add"] = function(Profiler)
			Profiler.Begin("Setup")
			local world = jecs.World.new()
			local pos = world:component()
			local vel = world:component()
			local ids = {}

			for i = 1, entities do
				local e = world:entity()
				world:add(e, pos)
				world:set(e, pos, { x = i, y = i, z = i })
				ids[i] = e
			end
			Profiler.End()

			Profiler.Begin("Adding")
			for i = 1, entities do
				world:add(ids[i], vel)
				world:set(ids[i], vel, { x = 1, y = 1, z = 1 })
			end
			Profiler.End()
		end,

		["Chronecs Component Remove"] = function(Profiler)
			Profiler.Begin("Setup")
			local world = chronecs.new()
			local pos = world:component()
			local vel = world:component()
			local ids = {}

			for i = 1, entities do
				local e = world:entity()
				world:add(e, pos)
				world:set(e, pos, { x = i, y = i, z = i })
				ids[i] = e
			end
			Profiler.End()

			Profiler.Begin("Removing")
			for i = 1, entities do
				world:remove(ids[i], vel)
			end
			Profiler.End()
		end,

		["Jecs Component Remove"] = function(Profiler)
			Profiler.Begin("Setup")
			local world = jecs.World.new()
			local pos = world:component()
			local vel = world:component()
			local ids = {}

			for i = 1, entities do
				local e = world:entity()
				world:add(e, pos)
				world:set(e, pos, { x = i, y = i, z = i })
				ids[i] = e
			end
			Profiler.End()

			Profiler.Begin("Removing")
			for i = 1, entities do
				world:remove(ids[i], vel)
			end
			Profiler.End()
		end,
	},
}
