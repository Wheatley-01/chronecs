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
	if len == 1 then
		return cached_masks[...]
	elseif len == 2 then
		local c1, c2 = ...
		return bor(cached_masks[c1], cached_masks[c2])
	elseif len == 3 then
		local c1, c2, c3 = ...
		return bor(cached_masks[c1], bor(cached_masks[c2], cached_masks[c3]))
	elseif len == 4 then
		local c1, c2, c3, c4 = ...
		return bor(bor(cached_masks[c1], cached_masks[c2]), bor(cached_masks[c3], cached_masks[c4]))
	elseif len == 5 then
		local c1, c2, c3, c4, c5 = ...
		return bor(
			bor(cached_masks[c1], cached_masks[c2]),
			bor(bor(cached_masks[c3], cached_masks[c4]), cached_masks[c5])
		)
	elseif len == 6 then
		local c1, c2, c3, c4, c5, c6 = ...
		return bor(
			bor(bor(cached_masks[c1], cached_masks[c2]), bor(cached_masks[c3], cached_masks[c4])),
			bor(cached_masks[c5], cached_masks[c6])
		)
	elseif len == 7 then
		local c1, c2, c3, c4, c5, c6, c7 = ...
		return bor(
			bor(bor(cached_masks[c1], cached_masks[c2]), bor(cached_masks[c3], cached_masks[c4])),
			bor(bor(cached_masks[c5], cached_masks[c6]), cached_masks[c7])
		)
	elseif len == 8 then
		local c1, c2, c3, c4, c5, c6, c7, c8 = ...
		return bor(
			bor(bor(cached_masks[c1], cached_masks[c2]), bor(cached_masks[c3], cached_masks[c4])),
			bor(bor(cached_masks[c5], cached_masks[c6]), bor(cached_masks[c7], cached_masks[c8]))
		)
	elseif len >= 60 then
		local z = { ... }
		local need = 0
		for i = 1, len do
			need = bor(need, cached_masks[z[i]])
		end
		return need
	else
		local need = 0
		for i = 1, len do
			need = bor(need, cached_masks[select(i, ...)])
		end
		return need
	end
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
	self.entities[nexte] = { [0] = 0, archetype = nil, row = nil }
	return nexte
end

local function get_or_create_archetype(self, mask)
	local archetype = self.archetypes_by_mask[mask]
	if archetype then
		return archetype
	end

	archetype = {
		mask = mask,
		entities = {},
		count = 0,
		components = {},
		entity_to_row = {},
	}

	for comp_id, comp_mask in pairs(self.masks) do
		if band(mask, comp_mask) ~= 0 then
			archetype.components[comp_id] = {}
		end
	end

	self.archetypes_by_mask[mask] = archetype
	table.insert(self.archetypes_list, archetype)

	for _, query_info in ipairs(self.query_cache) do
		local query_mask = query_info.mask
		if band(mask, query_mask) == query_mask then
			table.insert(query_info.matching_archetypes, archetype)
		end
	end

	return archetype
end

local function move_entity_to_archetype(self, e, old_archetype, new_archetype, new_mask)
	local entity_data = self.entities[e]

	if old_archetype then
		local old_row = entity_data.row
		local last_entity_in_old = old_archetype.entities[old_archetype.count]

		old_archetype.entities[old_row] = last_entity_in_old
		old_archetype.entity_to_row[last_entity_in_old] = old_row

		if last_entity_in_old ~= e then
			self.entities[last_entity_in_old].row = old_row

			for comp_id, column in pairs(old_archetype.components) do
				column[old_row] = column[old_archetype.count]
			end
		end

		old_archetype.entities[old_archetype.count] = nil
		old_archetype.entity_to_row[e] = nil

		for comp_id, column in pairs(old_archetype.components) do
			column[old_archetype.count] = nil
		end

		old_archetype.count = old_archetype.count - 1
	end

	local new_row = new_archetype.count + 1
	new_archetype.count = new_row
	new_archetype.entities[new_row] = e
	new_archetype.entity_to_row[e] = new_row

	entity_data.archetype = new_archetype
	entity_data.row = new_row
	entity_data[0] = new_mask

	local old_mask = old_archetype and old_archetype.mask or 0

	for comp_id, column in pairs(new_archetype.components) do
		local comp_mask = self.masks[comp_id]
		if band(old_mask, comp_mask) ~= 0 then
			local old_column = old_archetype.components[comp_id]
			local old_row = entity_data.row == new_row and old_archetype.entity_to_row[e] or entity_data.row
			column[new_row] = old_column and old_column[old_row]
				or self.data[comp_id].packed[self.data[comp_id].sparse[e]]
		else
			column[new_row] = self.data[comp_id].packed[self.data[comp_id].sparse[e]]
		end
	end
end

function world:delete(e)
	local entity_data = self.entities[e]
	if not entity_data then
		return
	end

	local archetype = entity_data.archetype
	if archetype then
		local row = entity_data.row
		local last_entity = archetype.entities[archetype.count]

		archetype.entities[row] = last_entity
		archetype.entity_to_row[last_entity] = row

		if last_entity ~= e then
			self.entities[last_entity].row = row

			for comp_id, column in pairs(archetype.components) do
				column[row] = column[archetype.count]
			end
		end

		archetype.entities[archetype.count] = nil
		archetype.entity_to_row[e] = nil

		for comp_id, column in pairs(archetype.components) do
			column[archetype.count] = nil
		end

		archetype.count = archetype.count - 1
	end

	local self_data = self.data
	for c, component in pairs(self_data) do
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

	self.entities[e] = nil
end

function world:add(e, ...)
	local entity_data = self.entities[e]
	local old_mask = entity_data[0]
	local new_mask = bulk_add(select("#", ...), old_mask, self.masks, ...)

	if new_mask ~= old_mask then
		local old_archetype = entity_data.archetype
		local new_archetype = get_or_create_archetype(self, new_mask)
		move_entity_to_archetype(self, e, old_archetype, new_archetype, new_mask)
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

		local entity_data = self.entities[e]
		local old_mask = entity_data[0]
		local new_mask = bor(old_mask, self.masks[c])

		if new_mask ~= old_mask then
			local old_archetype = entity_data.archetype
			local new_archetype = get_or_create_archetype(self, new_mask)
			move_entity_to_archetype(self, e, old_archetype, new_archetype, new_mask)
		else
			local archetype = entity_data.archetype
			if archetype and archetype.components[c] then
				archetype.components[c][entity_data.row] = data
			end
		end
	else
		component.packed[idx] = data

		local entity_data = self.entities[e]
		local archetype = entity_data.archetype
		if archetype and archetype.components[c] then
			archetype.components[c][entity_data.row] = data
		end
	end
end

function world:bulk_set(e, ...)
	local len = select("#", ...)
	local self_data = self.data
	local entity_data = self.entities[e]
	local old_mask = entity_data[0]
	local new_mask = old_mask

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
			new_mask = bor(new_mask, self.masks[c])
		else
			component.packed[idx] = data
		end
	end

	if new_mask ~= old_mask then
		local old_archetype = entity_data.archetype
		local new_archetype = get_or_create_archetype(self, new_mask)
		move_entity_to_archetype(self, e, old_archetype, new_archetype, new_mask)
	else
		local archetype = entity_data.archetype
		if archetype then
			for i = 1, len, 2 do
				local c = select(i, ...)
				local data = select(i + 1, ...)
				if archetype.components[c] then
					archetype.components[c][entity_data.row] = data
				end
			end
		end
	end
end

function world:get(e, c)
	local component = self.data[c]
	local idx = component.sparse[e]
	return idx and component.packed[idx]
end

function world:remove(e, ...)
	local entity_data = self.entities[e]
	local old_mask = entity_data[0]
	local new_mask = bulk_remove(select("#", ...), old_mask, self.masks, ...)

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

	if new_mask ~= old_mask then
		local old_archetype = entity_data.archetype
		local new_archetype = get_or_create_archetype(self, new_mask)
		move_entity_to_archetype(self, e, old_archetype, new_archetype, new_mask)
	end
end

function world:has(e, ...)
	local need = compute_mask(select("#", ...), self.masks, ...)
	return band(self.entities[e][0], need) == need
end

function world:view(...)
	local len = select("#", ...)
	local query_mask = compute_mask(len, self.masks, ...)

	local comp_ids = nil
	local query_info = nil
	local by_mask = self.query_cache_by_mask[query_mask]
	if by_mask then
		for _, qi in ipairs(by_mask) do
			local ci = qi.comp_ids
			if #ci == len then
				local ok = true
				for i = 1, len do
					if ci[i] ~= select(i, ...) then
						ok = false
						break
					end
				end
				if ok then
					query_info = qi
					break
				end
			end
		end
	end

	if not query_info then
		comp_ids = {}
		for i = 1, len do
			comp_ids[i] = select(i, ...)
		end

		query_info = {
			mask = query_mask,
			comp_ids = comp_ids,
			matching_archetypes = {},
		}

		table.insert(self.query_cache, query_info)
		self.query_cache_by_mask[query_mask] = self.query_cache_by_mask[query_mask] or {}
		table.insert(self.query_cache_by_mask[query_mask], query_info)

		for _, archetype in ipairs(self.archetypes_list) do
			if band(archetype.mask, query_mask) == query_mask then
				table.insert(query_info.matching_archetypes, archetype)
			end
		end
	end

	local matching_archetypes = query_info.matching_archetypes
	if #matching_archetypes == 0 then
		return function()
			return nil
		end
	end

	local archetype_idx = 1
	local current_archetype = matching_archetypes[1]
	local entity_idx = 0
	local count = current_archetype.count
	local entities = current_archetype.entities

	local current_cols = {}
	do
		local comps = current_archetype.components
		for i = 1, len do
			current_cols[i] = comps[query_info.comp_ids[i]]
		end
	end

	local result_buf = {}

	if len == 1 then
		local col1 = current_cols[1]
		return function()
			entity_idx = entity_idx + 1
			while entity_idx > count do
				archetype_idx = archetype_idx + 1
				if archetype_idx > #matching_archetypes then
					return nil
				end
				current_archetype = matching_archetypes[archetype_idx]
				entity_idx = 1

				entities = current_archetype.entities
				count = current_archetype.count
				local comps = current_archetype.components
				col1 = comps[query_info.comp_ids[1]]
				for i = 1, 1 do
					current_cols[i] = comps[query_info.comp_ids[i]]
				end
			end

			local e = entities[entity_idx]
			local idx = entity_idx
			return e, col1[idx]
		end
	elseif len == 2 then
		local col1, col2 = current_cols[1], current_cols[2]
		return function()
			entity_idx = entity_idx + 1
			while entity_idx > count do
				archetype_idx = archetype_idx + 1
				if archetype_idx > #matching_archetypes then
					return nil
				end
				current_archetype = matching_archetypes[archetype_idx]
				entity_idx = 1

				entities = current_archetype.entities
				count = current_archetype.count
				local comps = current_archetype.components
				col1 = comps[query_info.comp_ids[1]]
				col2 = comps[query_info.comp_ids[2]]
			end

			local e = entities[entity_idx]
			local idx = entity_idx
			return e, col1[idx], col2[idx]
		end
	elseif len == 3 then
		local col1, col2, col3 = current_cols[1], current_cols[2], current_cols[3]
		return function()
			entity_idx = entity_idx + 1
			while entity_idx > count do
				archetype_idx = archetype_idx + 1
				if archetype_idx > #matching_archetypes then
					return nil
				end
				current_archetype = matching_archetypes[archetype_idx]
				entity_idx = 1

				entities = current_archetype.entities
				count = current_archetype.count
				local comps = current_archetype.components
				col1 = comps[query_info.comp_ids[1]]
				col2 = comps[query_info.comp_ids[2]]
				col3 = comps[query_info.comp_ids[3]]
			end

			local e = entities[entity_idx]
			local idx = entity_idx
			return e, col1[idx], col2[idx], col3[idx]
		end
	elseif len == 4 then
		local col1, col2, col3, col4 = current_cols[1], current_cols[2], current_cols[3], current_cols[4]
		return function()
			entity_idx = entity_idx + 1
			while entity_idx > count do
				archetype_idx = archetype_idx + 1
				if archetype_idx > #matching_archetypes then
					return nil
				end
				current_archetype = matching_archetypes[archetype_idx]
				entity_idx = 1

				entities = current_archetype.entities
				count = current_archetype.count
				local comps = current_archetype.components
				col1 = comps[query_info.comp_ids[1]]
				col2 = comps[query_info.comp_ids[2]]
				col3 = comps[query_info.comp_ids[3]]
				col4 = comps[query_info.comp_ids[4]]
			end

			local e = entities[entity_idx]
			local idx = entity_idx
			return e, col1[idx], col2[idx], col3[idx], col4[idx]
		end
	elseif len == 5 then
		local col1, col2, col3, col4, col5 =
			current_cols[1], current_cols[2], current_cols[3], current_cols[4], current_cols[5]
		return function()
			entity_idx = entity_idx + 1
			while entity_idx > count do
				archetype_idx = archetype_idx + 1
				if archetype_idx > #matching_archetypes then
					return nil
				end
				current_archetype = matching_archetypes[archetype_idx]
				entity_idx = 1

				entities = current_archetype.entities
				count = current_archetype.count
				local comps = current_archetype.components
				col1 = comps[query_info.comp_ids[1]]
				col2 = comps[query_info.comp_ids[2]]
				col3 = comps[query_info.comp_ids[3]]
				col4 = comps[query_info.comp_ids[4]]
				col5 = comps[query_info.comp_ids[5]]
			end

			local e = entities[entity_idx]
			local idx = entity_idx
			return e, col1[idx], col2[idx], col3[idx], col4[idx], col5[idx]
		end
	elseif len == 6 then
		local col1, col2, col3, col4, col5, col6 =
			current_cols[1], current_cols[2], current_cols[3], current_cols[4], current_cols[5], current_cols[6]
		return function()
			entity_idx = entity_idx + 1
			while entity_idx > count do
				archetype_idx = archetype_idx + 1
				if archetype_idx > #matching_archetypes then
					return nil
				end
				current_archetype = matching_archetypes[archetype_idx]
				entity_idx = 1

				entities = current_archetype.entities
				count = current_archetype.count
				local comps = current_archetype.components
				col1 = comps[query_info.comp_ids[1]]
				col2 = comps[query_info.comp_ids[2]]
				col3 = comps[query_info.comp_ids[3]]
				col4 = comps[query_info.comp_ids[4]]
				col5 = comps[query_info.comp_ids[5]]
				col6 = comps[query_info.comp_ids[6]]
			end

			local e = entities[entity_idx]
			local idx = entity_idx
			return e, col1[idx], col2[idx], col3[idx], col4[idx], col5[idx], col6[idx]
		end
	elseif len == 7 then
		local col1, col2, col3, col4, col5, col6, col7 =
			current_cols[1],
			current_cols[2],
			current_cols[3],
			current_cols[4],
			current_cols[5],
			current_cols[6],
			current_cols[7]
		return function()
			entity_idx = entity_idx + 1
			while entity_idx > count do
				archetype_idx = archetype_idx + 1
				if archetype_idx > #matching_archetypes then
					return nil
				end
				current_archetype = matching_archetypes[archetype_idx]
				entity_idx = 1

				entities = current_archetype.entities
				count = current_archetype.count
				local comps = current_archetype.components
				col1 = comps[query_info.comp_ids[1]]
				col2 = comps[query_info.comp_ids[2]]
				col3 = comps[query_info.comp_ids[3]]
				col4 = comps[query_info.comp_ids[4]]
				col5 = comps[query_info.comp_ids[5]]
				col6 = comps[query_info.comp_ids[6]]
				col7 = comps[query_info.comp_ids[7]]
			end

			local e = entities[entity_idx]
			local idx = entity_idx
			return e, col1[idx], col2[idx], col3[idx], col4[idx], col5[idx], col6[idx], col7[idx]
		end
	elseif len == 8 then
		local col1, col2, col3, col4, col5, col6, col7, col8 =
			current_cols[1],
			current_cols[2],
			current_cols[3],
			current_cols[4],
			current_cols[5],
			current_cols[6],
			current_cols[7],
			current_cols[8]
		return function()
			entity_idx = entity_idx + 1
			while entity_idx > count do
				archetype_idx = archetype_idx + 1
				if archetype_idx > #matching_archetypes then
					return nil
				end
				current_archetype = matching_archetypes[archetype_idx]
				entity_idx = 1

				entities = current_archetype.entities
				count = current_archetype.count
				local comps = current_archetype.components
				col1 = comps[query_info.comp_ids[1]]
				col2 = comps[query_info.comp_ids[2]]
				col3 = comps[query_info.comp_ids[3]]
				col4 = comps[query_info.comp_ids[4]]
				col5 = comps[query_info.comp_ids[5]]
				col6 = comps[query_info.comp_ids[6]]
				col7 = comps[query_info.comp_ids[7]]
				col8 = comps[query_info.comp_ids[8]]
			end

			local e = entities[entity_idx]
			local idx = entity_idx
			return e, col1[idx], col2[idx], col3[idx], col4[idx], col5[idx], col6[idx], col7[idx], col8[idx]
		end
	else
		local comp_ids_local = query_info.comp_ids
		return function()
			entity_idx = entity_idx + 1
			while entity_idx > count do
				archetype_idx = archetype_idx + 1
				if archetype_idx > #matching_archetypes then
					return nil
				end
				current_archetype = matching_archetypes[archetype_idx]
				entity_idx = 1

				entities = current_archetype.entities
				count = current_archetype.count
				local comps = current_archetype.components
				for i = 1, len do
					current_cols[i] = comps[comp_ids_local[i]]
				end
			end

			local e = entities[entity_idx]
			local idx = entity_idx

			result_buf[1] = e
			for i = 1, len do
				result_buf[i + 1] = current_cols[i][idx]
			end
			return unpack(result_buf, 1, len + 1)
		end
	end
end

function world:exclude(exclude_len, ...)
	local include_len = select("#", ...) - exclude_len
	local need = compute_mask(include_len, self.masks, ...)
	local exclude_mask = 0

	for i = include_len + 1, include_len + exclude_len do
		exclude_mask = bor(exclude_mask, self.masks[select(i, ...)])
	end

	local matching_archetypes = {}
	for _, archetype in next, self.archetypes_list do
		if band(archetype.mask, need) == need and band(archetype.mask, exclude_mask) == 0 then
			table.insert(matching_archetypes, archetype)
		end
	end

	if #matching_archetypes == 0 then
		return function()
			return nil
		end
	end

	local comp_ids = { ... }
	local archetype_idx = 1
	local current_archetype = matching_archetypes[1]
	local entity_idx = 0

	return function()
		entity_idx = entity_idx + 1

		while entity_idx > current_archetype.count do
			archetype_idx = archetype_idx + 1
			if archetype_idx > #matching_archetypes then
				return nil
			end
			current_archetype = matching_archetypes[archetype_idx]
			entity_idx = 1
		end

		local e = current_archetype.entities[entity_idx]
		local result = { e }
		local comps = current_archetype.components
		local idx = entity_idx

		for i = 1, include_len do
			result[i + 1] = comps[comp_ids[i]][idx]
		end

		return unpack(result, 1, include_len + 1)
	end
end

function ecs.new()
	return setmetatable({
		entities = {},
		data = {},
		masks = {},
		archetypes_by_mask = {},
		archetypes_list = {},
		query_cache = {},
		query_cache_by_mask = {},
		nextc = 0,
		nexte = 0,
	}, world)
end

return ecs