E2Lib.RegisterExtension("find", true, "Allows an E2 to search for entities matching a filter.")

local function table_IsEmpty(t) return not next(t) end

local filterList = E2Lib.filterList

local function replace_match(a,b)
	return string.match( string.Replace(a,"-","__"), string.Replace(b,"-","__") )
end

-- -- some generic filter criteria -- --

local function filter_all() return true end
local function filter_none() return false end

local forbidden_classes = {
	--[[
	["info_apc_missile_hint"] = true,
	["info_camera_link"] = true,
	["info_constraint_anchor"] = true,
	["info_hint"] = true,
	["info_intermission"] = true,
	["info_ladder_dismount"] = true,
	["info_landmark"] = true,
	["info_lighting"] = true,
	["info_mass_center"] = true,
	["info_no_dynamic_shadow"] = true,
	["info_node"] = true,
	["info_node_air"] = true,
	["info_node_air_hint"] = true,
	["info_node_climb"] = true,
	["info_node_hint"] = true,
	["info_node_link"] = true,
	["info_node_link_controller"] = true,
	["info_npc_spawn_destination"] = true,
	["info_null"] = true,
	["info_overlay"] = true,
	["info_particle_system"] = true,
	["info_projecteddecal"] = true,
	["info_snipertarget"] = true,
	["info_target"] = true,
	["info_target_gunshipcrash"] = true,
	["info_teleport_destination"] = true,
	["info_teleporter_countdown"] = true,
	]]
	["info_player_allies"] = true,
	["info_player_axis"] = true,
	["info_player_combine"] = true,
	["info_player_counterterrorist"] = true,
	["info_player_deathmatch"] = true,
	["info_player_logo"] = true,
	["info_player_rebel"] = true,
	["info_player_start"] = true,
	["info_player_terrorist"] = true,
	["info_player_blu"] = true,
	["info_player_red"] = true,
	["prop_dynamic"] = true,
	["physgun_beam"] = true,
	["player_manager"] = true,
	["predicted_viewmodel"] = true,
	["gmod_ghost"] = true,
}
local function filter_default(self)
	local chip = self.entity
	return function(ent)
		if forbidden_classes[ent:GetClass()] then return false end

		if ent == chip then return false end
		return true
	end
end

-- -- some filter criterion generators -- --

-- Generates a filter that filters out everything not in a lookup table.
local function filter_in_lookup(lookup)
	if table_IsEmpty(lookup) then return filter_none end

	return function(ent)
		return lookup[ent]
	end
end

-- Generates a filter that filters out everything in a lookup table.
local function filter_not_in_lookup(lookup)
	if table_IsEmpty(lookup) then return filter_all end

	return function(ent)
		return not lookup[ent]
	end
end

-- Generates a filter that filters out everything not in a lookup table.
local function filter_function_result_in_lookup(lookup, func)
	if table_IsEmpty(lookup) then return filter_none end

	return function(ent)
		return lookup[func(ent)]
	end
end

-- Generates a filter that filters out everything in a lookup table.
local function filter_function_result_not_in_lookup(lookup, func)
	if table_IsEmpty(lookup) then return filter_all end

	return function(ent)
		return not lookup[func(ent)]
	end
end

-- checks if binary_predicate(func(ent), key) matches for any of the keys in the lookup table. Returns false if it does.
local function filter_binary_predicate_match_none(lookup, func, binary_predicate)
	if table_IsEmpty(lookup) then return filter_all end

	return function(a)
		a = func(a)
		for b,_ in pairs(lookup) do
			if binary_predicate(a, b) then return false end
		end
		return true
	end
end

-- checks if binary_predicate(func(ent), key) matches for any of the keys in the lookup table. Returns true if it does.
local function filter_binary_predicate_match_one(lookup, func, binary_predicate)
	if table_IsEmpty(lookup) then return filter_none end

	return function(a)
		a = func(a)
		for b,_ in pairs(lookup) do
			if binary_predicate(a, b) then return true end
		end
		return false
	end
end


-- -- filter criterion combiners -- --

local _filter_and = {
	[0] = function() return filter_all end,
	function(f1)                   return f1 end,
	function(f1,f2)                return function(v) return f1(v) and f2(v) end end,
	function(f1,f2,f3)             return function(v) return f1(v) and f2(v) and f3(v) end end,
	function(f1,f2,f3,f4)          return function(v) return f1(v) and f2(v) and f3(v) and f4(v) end end,
	function(f1,f2,f3,f4,f5)       return function(v) return f1(v) and f2(v) and f3(v) and f4(v) and f5(v) end end,
	function(f1,f2,f3,f4,f5,f6)    return function(v) return f1(v) and f2(v) and f3(v) and f4(v) and f5(v) and f6(v) end end,
	function(f1,f2,f3,f4,f5,f6,f7) return function(v) return f1(v) and f2(v) and f3(v) and f4(v) and f5(v) and f6(v) and f7(v) end end,
}

-- Usage: filter = filter_and(filter1, filter2, filter3)
local function filter_and(...)
	local args = {...}

	-- filter out all filter_all entries
	filterList(args, function(f)
		if f == filter_none then
			args = { filter_none } -- If a filter_none is in the list, we can discard all other filters.
		end
		return f ~= filter_all
	end)

	local combiner = _filter_and[#args]
	if not combiner then return nil end -- TODO: write generic combiner
	return combiner(unpack(args))
end

local _filter_or = {
	[0] = function() return filter_none end,
	function(f1)                   return f1 end,
	function(f1,f2)                return function(v) return f1(v) or f2(v) end end,
	function(f1,f2,f3)             return function(v) return f1(v) or f2(v) or f3(v) end end,
	function(f1,f2,f3,f4)          return function(v) return f1(v) or f2(v) or f3(v) or f4(v) end end,
	function(f1,f2,f3,f4,f5)       return function(v) return f1(v) or f2(v) or f3(v) or f4(v) or f5(v) end end,
	function(f1,f2,f3,f4,f5,f6)    return function(v) return f1(v) or f2(v) or f3(v) or f4(v) or f5(v) or f6(v) end end,
	function(f1,f2,f3,f4,f5,f6,f7) return function(v) return f1(v) or f2(v) or f3(v) or f4(v) or f5(v) or f6(v) or f7(v) end end,
}

-- Usage: filter = filter_or(filter1, filter2, filter3)
local function filter_or(...)
	local args = {...}

	-- filter out all filter_none entries
	filterList(args, function(f)
		if f == filter_all then
			args = { filter_all } -- If a filter_all is in the list, we can discard all other filters.
		end
		return f ~= filter_none
	end)

	local combiner = _filter_or[#args]
	if not combiner then return nil end -- TODO: write generic combiner
	return combiner(unpack(args))
end

local function invalidate_filters(self)
	-- Update the filters the next time they are used.
	self.data.findfilter = nil
end

-- This function should be called after the black- or whitelists have changed.
local function update_filters(self)
	-- Do not update again until the filters are invalidated the next time.

	local find = self.data.find

	---------------------
	--    blacklist    --
	---------------------

	-- blacklist for single entities
	local bl_entity_filter = filter_not_in_lookup(find.bl_entity)
	-- blacklist for a player's props
	local bl_owner_filter = filter_function_result_not_in_lookup(find.bl_owner, function(ent) return getOwner(self,ent) end)

	-- blacklist for models
	local bl_model_filter = filter_binary_predicate_match_none(find.bl_model, function(ent) return string.lower(ent:GetModel() or "") end, replace_match)
	-- blacklist for classes
	local bl_class_filter = filter_binary_predicate_match_none(find.bl_class, function(ent) return string.lower(ent:GetClass()) end, replace_match)

	-- combine all blacklist filters (done further down)
	--local filter_blacklist = filter_and(bl_entity_filter, bl_owner_filter, bl_model_filter, bl_class_filter)

	---------------------
	--    whitelist    --
	---------------------

	local filter_whitelist = filter_all

	-- if not all whitelists are empty, use the whitelists.
	local whiteListInUse = not (table_IsEmpty(find.wl_entity) and table_IsEmpty(find.wl_owner) and table_IsEmpty(find.wl_model) and table_IsEmpty(find.wl_class))

	if whiteListInUse then
		-- blacklist for single entities
		local wl_entity_filter = filter_in_lookup(find.wl_entity)
		-- blacklist for a player's props
		local wl_owner_filter = filter_function_result_in_lookup(find.wl_owner, function(ent) return getOwner(self,ent) end)

		-- blacklist for models
		local wl_model_filter = filter_binary_predicate_match_one(find.wl_model, function(ent) return string.lower(ent:GetModel() or "") end, replace_match)
		-- blacklist for classes
		local wl_class_filter = filter_binary_predicate_match_one(find.wl_class, function(ent) return string.lower(ent:GetClass()) end, replace_match)

		-- combine all whitelist filters
		filter_whitelist = filter_or(wl_entity_filter, wl_owner_filter, wl_model_filter, wl_class_filter)
	end
	---------------------

	-- finally combine all filters
	--self.data.findfilter = filter_and(find.filter_default, filter_blacklist, filter_whitelist)
	self.data.findfilter = filter_and(find.filter_default, bl_entity_filter, bl_owner_filter, bl_model_filter, bl_class_filter, filter_whitelist)
end

local function applyFindList(self, findlist)
	local findfilter = self.data.findfilter
	if not findfilter then
		update_filters(self)
		findfilter = self.data.findfilter
	end
	filterList(findlist, findfilter)

	self.data.findlist = findlist
	return #findlist
end

--[[************************************************************************]]--


local _findrate = CreateConVar("wire_expression2_find_rate", 0.05,{FCVAR_ARCHIVE,FCVAR_NOTIFY})
local _maxfinds = CreateConVar("wire_expression2_find_max",10,{FCVAR_ARCHIVE,FCVAR_NOTIFY})
local function findrate() return _findrate:GetFloat() end
local function maxfinds() return _maxfinds:GetInt() end

local chiplist = {}

registerCallback("construct", function(self)
	self.data.find = {
		filter_default = filter_default(self),
		bl_entity = {},
		bl_owner = {},
		bl_model = {},
		bl_class = {},

		wl_entity = {},
		wl_owner = {},
		wl_model = {},
		wl_class = {},
	}
	invalidate_filters(self)
	self.data.findnext = 0
	self.data.findlist = {}
	self.data.findcount = maxfinds()
	chiplist[self.data] = true
end)

registerCallback("destruct", function(self)
	chiplist[self.data] = nil
end)

hook.Add("EntityRemoved", "wire_expression2_find_EntityRemoved", function(ent)
	for chip,_ in pairs(chiplist) do
		local find = chip.find
		find.bl_entity[ent] = nil
		find.bl_owner[ent] = nil
		find.wl_entity[ent] = nil
		find.wl_owner[ent] = nil

		filterList(chip.findlist, function(v) return ent ~= v end)
	end
end)


--[[************************************************************************]]--

function query_blocked(self, update)
	if (update) then
		if (self.data.findcount > 0) then
			self.data.findcount = self.data.findcount - 1
			return false
		else
			return true
		end
	end
	return (self.data.findcount < 1)
end


--[[************************************************************************]]--
__e2setcost(30)

--- Find all entities with the given class
e2function number findByClass(string class)
	if query_blocked(self, 1) then return 0 end
	return applyFindList(self, ents.FindByClass(class))
end

--[[************************************************************************]]--

local function findPlayer(name)
	name = string.lower(name)
	return filterList(player.GetAll(), function(ent) return string.find(string.lower(ent:GetName()), name,1,true) end)[1]
end

--- Returns the player with the given name, this is an exception to the rule
e2function entity findPlayerByName(string name)
	if query_blocked(self, 1) then return nil end
	return findPlayer(name)
end

--- Returns the player with the given SteamID
e2function entity findPlayerBySteamID(string id)
	if query_blocked(self, 1) then return NULL end
	return player.GetBySteamID(id) or NULL
end

--- Returns the player with the given SteamID64
e2function entity findPlayerBySteamID64(string id)
	if query_blocked(self, 1) then return NULL end
	return player.GetBySteamID64(id) or NULL
end

--[[************************************************************************]]--
__e2setcost(10)

--- Exclude entities with this class (or partial class name) from future finds
e2function void findExcludeClass(string class)
	self.data.find.bl_class[string.lower(class)] = true
	invalidate_filters(self)
end

--[[************************************************************************]]--


--- Remove entities with this class (or partial class name) from the blacklist
e2function void findAllowClass(string class)
	self.data.find.bl_class[string.lower(class)] = nil
	invalidate_filters(self)
end

--[[************************************************************************]]--

--- Include entities with this class (or partial class name) in future finds, and remove others not in the whitelist
e2function void findIncludeClass(string class)
	self.data.find.wl_class[string.lower(class)] = true
	invalidate_filters(self)
end

--[[************************************************************************]]--

--- Remove entities with this class (or partial class name) from the whitelist
e2function void findDisallowClass(string class)
	self.data.find.wl_class[string.lower(class)] = nil
	invalidate_filters(self)
end

--[[************************************************************************]]--
__e2setcost(5)

local function applyClip(self, filter)
	local findlist = self.data.findlist
	self.prf = self.prf + #findlist * 5

	filterList(findlist, filter)

	return #findlist
end

--- Filters the list of entities by removing all entities NOT on the positive side of the defined plane. (Plane origin, vector perpendicular to the plane) You can define any convex hull using this.
e2function number findClipToRegion(vector origin, vector perpendicular)
	origin = Vector(origin[1], origin[2], origin[3])
	perpendicular = Vector(perpendicular[1], perpendicular[2], perpendicular[3])

	local perpdot = perpendicular:Dot(origin)

	return applyClip(self, function(ent)
		if !IsValid(ent) then return false end
		return perpdot < perpendicular:Dot(ent:GetPos())
	end)
end

-- inrange used in findClip*Box (below)
local function inrange( vec1, vecmin, vecmax )
	if (vec1.x < vecmin.x) then return false end
	if (vec1.y < vecmin.y) then return false end
	if (vec1.z < vecmin.z) then return false end

	if (vec1.x > vecmax.x) then return false end
	if (vec1.y > vecmax.y) then return false end
	if (vec1.z > vecmax.z) then return false end

	return true
end

-- If vecmin is greater than vecmax, flip it
local function sanitize( vecmin, vecmax )
	for I=1, 3 do
		if (vecmin[I] > vecmax[I]) then
			local temp = vecmin[I]
			vecmin[I] = vecmax[I]
			vecmax[I] = temp
		end
	end
	return vecmin, vecmax
end

-- Filters the list of entities by removing all entities within the specified box
e2function number findClipFromBox( vector min, vector max )

	min, max = sanitize( min, max )

	min = Vector(min[1], min[2], min[3])
	max = Vector(max[1], max[2], max[3])

	return applyClip( self, function(ent)
		return !inrange(ent:GetPos(),min,max)
	end)
end

-- Filters the list of entities by removing all entities not within the specified box
e2function number findClipToBox( vector min, vector max )

	min, max = sanitize( min, max )

	min = Vector(min[1], min[2], min[3])
	max = Vector(max[1], max[2], max[3])

	return applyClip( self, function(ent)
		return inrange(ent:GetPos(),min,max)
	end)
end

-- Filters the list of entities by removing all entities equal to one of these entities
e2function number findClipFromEntities( array entities )
	local lookup = {}
	self.prf = self.prf + #entities / 3
	for k,v in ipairs( entities ) do lookup[v] = true end
	return applyClip( self, function( ent )
		if !IsValid(ent) then return false end
		return !lookup[ent]
	end)
end

-- Filters the list of entities by removing all entities not equal to one of these entities
e2function number findClipToEntities( array entities )
	local lookup = {}
	self.prf = self.prf + #entities / 3
	for k,v in ipairs( entities ) do lookup[v] = true end
	return applyClip( self, function( ent )
		if !IsValid(ent) then return false end
		return lookup[ent]
	end)
end
