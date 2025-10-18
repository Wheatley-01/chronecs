--!native
--!optimize 2

local ecs = {}

local band, bor, bnot, lshift = bit32.band, bit32.bor, bit32.bnot, bit32.lshift

local function bulk_add(len, mask, cached_masks, ...)
	if len >= 60 then
		local z = {...}
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
		local z = {...}
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
		local z = {...}
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
	self.data[nextc] = {sparse = {}, dense = {}, packed = {}, n = 0}
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
	self.entities[nexte] = {[0] = 0}
	return nexte
end

function world:delete(e)
	local entities = self.entities
	local data = entities[e]
	if not data then return end

	local mask = data[0]
	local archetypes = self.archetypes
	local arch = archetypes[mask]

	if arch then
		local idx = arch.sparse[e]
		if idx then
			local n = arch.n
			local last = arch.dense[n]
			local dense = arch.dense
			local sparse = arch.sparse
			dense[idx] = last
			sparse[last] = idx
			dense[n] = nil
			sparse[e] = nil
			arch.n = n - 1
		end
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
	local new_mask = bulk_add(select('#', ...), old_mask, self.masks, ...)
	data[0] = new_mask

	if old_mask ~= new_mask then
		local archetypes = self.archetypes
		local old_arch = archetypes[old_mask]
		if old_arch then
			local idx = old_arch.sparse[e]
			if idx then
				local n = old_arch.n
				local last = old_arch.dense[n]
				local old_dense = old_arch.dense
				local old_sparse = old_arch.sparse
				old_dense[idx] = last
				old_sparse[last] = idx
				old_dense[n] = nil
				old_sparse[e] = nil
				old_arch.n = n - 1
			end
		end

		local new_arch = archetypes[new_mask]
		if not new_arch then
			new_arch = {sparse = {}, dense = {}, n = 0, mask = new_mask}
			archetypes[new_mask] = new_arch
		end
		local n = new_arch.n + 1
		new_arch.n = n
		new_arch.dense[n] = e
		new_arch.sparse[e] = n
	end
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
	local len = select('#', ...)
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
	local new_mask = bulk_remove(select('#', ...), old_mask, self.masks, ...)
	data[0] = new_mask

	if old_mask ~= new_mask then
		local archetypes = self.archetypes
		local old_arch = archetypes[old_mask]
		if old_arch then
			local idx = old_arch.sparse[e]
			if idx then
				local n = old_arch.n
				local last = old_arch.dense[n]
				local old_dense = old_arch.dense
				local old_sparse = old_arch.sparse
				old_dense[idx] = last
				old_sparse[last] = idx
				old_dense[n] = nil
				old_sparse[e] = nil
				old_arch.n = n - 1
			end
		end

		local new_arch = archetypes[new_mask]
		if not new_arch then
			new_arch = {sparse = {}, dense = {}, n = 0, mask = new_mask}
			archetypes[new_mask] = new_arch
		end
		local n = new_arch.n + 1
		new_arch.n = n
		new_arch.dense[n] = e
		new_arch.sparse[e] = n
	end

	local len = select('#', ...)
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
	local need = compute_mask(select('#', ...), self.masks, ...)
	return band(self.entities[e][0], need) == need
end

function world:view(...)
	local len = select('#', ...)
	local need = compute_mask(len, self.masks, ...)
	local archetypes = self.archetypes
	local query_cache = self.query_cache

	local cached = query_cache[need]
	local smallest_arch

	if cached then
		smallest_arch = cached
	else
		local min_count = math.huge
		for mask, arch in next, archetypes do
			if arch.n > 0 and band(mask, need) == need then
				if arch.n < min_count then
					min_count = arch.n
					smallest_arch = arch
				end
			end
		end
		query_cache[need] = smallest_arch
	end

	if not smallest_arch then
		return function() return nil end
	end

	local self_data = self.data
	local components = {...}
	local comp_sparse = {}
	local comp_packed = {}

	for i = 1, len do
		local comp = self_data[components[i]]
		comp_sparse[i] = comp.sparse
		comp_packed[i] = comp.packed
	end

	local current_dense = smallest_arch.dense
	local current_n = smallest_arch.n
	local entity_idx = 0

	return function()
		entity_idx = entity_idx + 1
		if entity_idx > current_n then
			return nil
		end

		local e = current_dense[entity_idx]
		local result = {e}
		for i = 1, len do
			result[i + 1] = comp_packed[i][comp_sparse[i][e]]
		end

		return unpack(result, 1, len+1)
	end
end

function world:exclude(exclude_len, ...)
	local include_len = select('#', ...) - exclude_len
	local need = compute_mask(include_len, self.masks, ...)
	local exclude_mask = 0

	for i = include_len + 1, include_len + exclude_len do
		exclude_mask = bor(exclude_mask, self.masks[select(i, ...)])
	end

	local archetypes = self.archetypes
	local query_cache = self.query_cache
	local cache_key = need + lshift(exclude_mask, 16)

	local cached = query_cache[cache_key]
	local matching_archs

	if cached then
		matching_archs = cached
	else
		matching_archs = {}
		local arch_count = 0

		for mask, arch in next, archetypes do
			if arch.n > 0 and band(mask, need) == need and band(mask, exclude_mask) == 0 then
				arch_count = arch_count + 1
				matching_archs[arch_count] = arch
			end
		end

		query_cache[cache_key] = matching_archs
	end

	local arch_count = #matching_archs
	local arch_idx = 0
	local entity_idx = 0
	local current_arch
	local current_dense
	local current_n = 0
	local self_data = self.data
	local components = {...}
	local comp_sparse = {}
	local comp_packed = {}

	for i = 1, include_len do
		local comp = self_data[components[i]]
		comp_sparse[i] = comp.sparse
		comp_packed[i] = comp.packed
	end

	return function()
		entity_idx = entity_idx + 1
		while entity_idx > current_n do
			arch_idx = arch_idx + 1
			if arch_idx > arch_count then
				return nil
			end
			current_arch = matching_archs[arch_idx]
			current_dense = current_arch.dense
			current_n = current_arch.n
			entity_idx = 1
		end
		local e = current_dense[entity_idx]
		local result = {e}
		for i = 1, include_len do
			result[i + 1] = comp_packed[i][comp_sparse[i][e]]
		end

		return unpack(result, 1, include_len+1)
	end	
end

function ecs.new()
	return setmetatable({
		entities = {},
		data = {},
		masks = {},
		archetypes = {},
		query_cache = {},
		nextc = 0,
		nexte = 0
	}, world)
end

return ecs
