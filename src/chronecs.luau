--!native
--!optimize 2

local ecs = {}

local band, bor, bnot, lshift = bit32.band, bit32.bor, bit32.bnot, bit32.lshift

local function bulk_add(len, mask, cached_masks, ...)
	if len >= 60 then
		local z = { ... }
		for i = 1, len do
			mask = bor(mask, cached_masks[z[i]])
		end
		return mask
	else
		for i = 1, len do
			mask = bor(mask, cached_masks[select(i, ...)])
		end
		return mask
	end
end

local function bulk_remove(len, mask, cached_masks, ...)
	local need = 0
	if len >= 60 then
		local z = { ... }
		for i = 1, len do
			need = bor(need, cached_masks[z[i]])
		end
	else
		for i = 1, len do
			need = bor(need, cached_masks[select(i, ...)])
		end
	end
	return band(mask, bnot(need))
end

local function compute_mask(len, cached_masks, ...)
	local need = 0
	if len >= 60 then
		local z = { ... }
		for i = 1, len do
			need = bor(need, cached_masks[z[i]])
		end
	else
		for i = 1, len do
			need = bor(need, cached_masks[select(i, ...)])
		end
	end
	return need
end

local world = {}
world.__index = world

function world:component()
	local nextc = self.nextc + 1
	self.nextc = nextc
	self.data[nextc] = { sparse = {}, dense = {}, packed = {}, n = 0 }
	self.masks[nextc] = lshift(1, nextc - 1)
	return nextc
end

function world:tag()
	local nextc = self.nextc + 1
	self.nextc = nextc
	self.masks[nextc] = lshift(1, nextc - 1)
	return nextc
end

function world:entity()
	local nexte = self.nexte + 1
	self.nexte = nexte
	self.entities[nexte] = { [0] = 0 }
	return nexte
end

function world:delete(e)
	local entities = self.entities
	local data = entities[e]
	if not data then
		return
	end

	local self_data = self.data
	for c, component in next, self_data do
		local sparse = component.sparse
		local idx = sparse[e]
		if idx then
			local n = component.n
			local dense = component.dense
			local packed = component.packed
			local last_e = dense[n]

			dense[idx] = last_e
			packed[idx] = packed[n]
			sparse[last_e] = idx

			sparse[e] = nil
			dense[n] = nil
			packed[n] = nil
			component.n = n - 1
		end
	end

	entities[e] = nil
end

function world:add(e, ...)
	local entities = self.entities
	local data = entities[e]
	local old_mask = data[0]
	local new_mask = bulk_add(select("#", ...), old_mask, self.masks, ...)
	data[0] = new_mask
end

function world:set(e, c, data)
	local component = self.data[c]
	local sparse = component.sparse
	local idx = sparse[e]

	if not idx then
		local n = component.n + 1
		component.n = n
		sparse[e] = n
		component.dense[n] = e
		component.packed[n] = data
	else
		component.packed[idx] = data
	end
end

function world:bulk_set(e, ...)
	local len = select("#", ...)
	local self_data = self.data
	for i = 1, len, 2 do
		local c = select(i, ...)
		local data = select(i + 1, ...)
		local component = self_data[c]
		local sparse = component.sparse
		local idx = sparse[e]

		if not idx then
			local n = component.n + 1
			component.n = n
			sparse[e] = n
			component.dense[n] = e
			component.packed[n] = data
		else
			component.packed[idx] = data
		end
	end
end

function world:get(e, c)
	local component = self.data[c]
	local idx = component.sparse[e]
	return idx and component.packed[idx]
end

function world:remove(e, ...)
	local entities = self.entities
	local data = entities[e]
	local old_mask = data[0]
	local new_mask = bulk_remove(select("#", ...), old_mask, self.masks, ...)
	data[0] = new_mask

	local len = select("#", ...)
	local self_data = self.data
	for i = 1, len do
		local c = select(i, ...)
		local component = self_data[c]
		if component then
			local sparse = component.sparse
			local idx = sparse[e]

			if idx then
				local n = component.n
				local last_e = component.dense[n]
				local dense = component.dense
				local packed = component.packed

				dense[idx] = last_e
				packed[idx] = packed[n]
				sparse[last_e] = idx

				sparse[e] = nil
				dense[n] = nil
				packed[n] = nil
				component.n = n - 1
			end
		end
	end
end

function world:has(e, ...)
	local need = compute_mask(select("#", ...), self.masks, ...)
	return band(self.entities[e][0], need) == need
end

function world:view(...)
	local len = select("#", ...)
	local need = compute_mask(len, self.masks, ...)
	local self_data = self.data
	local components = { ... }

	local min_count = math.huge
	local min_idx = 1

	for i = 1, len do
		local comp = self_data[components[i]]
		if comp.n < min_count then
			min_count = comp.n
			min_idx = i
		end
	end

	if min_count == 0 then
		return function()
			return nil
		end
	end

	local shortest_comp = self_data[components[min_idx]]
	local shortest_dense = shortest_comp.dense
	local shortest_n = shortest_comp.n

	local comp_sparse = {}
	local comp_packed = {}

	for i = 1, len do
		local comp = self_data[components[i]]
		comp_sparse[i] = comp.sparse
		comp_packed[i] = comp.packed
	end

	local entity_idx = 0

	return function()
		entity_idx = entity_idx + 1
		if entity_idx > shortest_n then
			return nil
		end

		local e = shortest_dense[entity_idx]

		for i = 1, len do
			if comp_sparse[i][e] == nil then
				entity_idx = entity_idx + 1
				while entity_idx <= shortest_n do
					e = shortest_dense[entity_idx]
					local found = true
					for j = 1, len do
						if comp_sparse[j][e] == nil then
							found = false
							break
						end
					end
					if found then
						break
					end
					entity_idx = entity_idx + 1
				end
				if entity_idx > shortest_n then
					return nil
				end
				break
			end
		end

		local result = { e }
		for i = 1, len do
			result[i + 1] = comp_packed[i][comp_sparse[i][e]]
		end

		return unpack(result, 1, len + 1)
	end
end

function world:exclude(exclude_len, ...)
	local include_len = select("#", ...) - exclude_len
	local need = compute_mask(include_len, self.masks, ...)
	local exclude_mask = 0

	for i = include_len + 1, include_len + exclude_len do
		exclude_mask = bor(exclude_mask, self.masks[select(i, ...)])
	end

	local self_data = self.data
	local components = { ... }

	local min_count = math.huge
	local min_idx = 1

	for i = 1, include_len do
		local comp = self_data[components[i]]
		if comp.n < min_count then
			min_count = comp.n
			min_idx = i
		end
	end

	if min_count == 0 then
		return function()
			return nil
		end
	end

	local shortest_comp = self_data[components[min_idx]]
	local shortest_dense = shortest_comp.dense
	local shortest_n = shortest_comp.n

	local comp_sparse = {}
	local comp_packed = {}

	for i = 1, include_len do
		local comp = self_data[components[i]]
		comp_sparse[i] = comp.sparse
		comp_packed[i] = comp.packed
	end

	local entity_idx = 0

	return function()
		entity_idx = entity_idx + 1
		while entity_idx <= shortest_n do
			local e = shortest_dense[entity_idx]

			local valid = true
			for i = 1, include_len do
				if comp_sparse[i][e] == nil then
					valid = false
					break
				end
			end

			if valid then
				local e_mask = self.entities[e][0]
				if band(e_mask, exclude_mask) == 0 then
					local result = { e }
					for i = 1, include_len do
						result[i + 1] = comp_packed[i][comp_sparse[i][e]]
					end
					return unpack(result, 1, include_len + 1)
				end
			end

			entity_idx = entity_idx + 1
		end
		return nil
	end
end

function ecs.new()
	return setmetatable({
		entities = {},
		data = {},
		masks = {},
		nextc = 0,
		nexte = 0,
	}, world)
end

return ecs
