--[[
    NutScript is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    NutScript is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with NutScript.  If not, see <http://www.gnu.org/licenses/>.
--]]

nut.item = nut.item or {}
nut.item.list = nut.item.list or {}
nut.item.base = nut.item.base or {}
nut.item.instances = nut.item.instances or {}
nut.item.inventories = nut.item.inventories or {
	[0] = {}
}
nut.item.inventoryTypes = nut.item.inventoryTypes or {}

nut.util.include("nutscript/gamemode/core/meta/sh_item.lua")

function nut.item.instance(index, uniqueID, data, x, y, callback)
	if (!uniqueID or nut.item.list[uniqueID]) then
		nut.db.insertTable({
			_invID = index,
			_uniqueID = uniqueID,
			_data = data,
			_x = x,
			_y = y
		}, function(data, itemID)
			local item = nut.item.new(uniqueID, itemID)

			if (item) then
				item.invID = index

				if (callback) then
					callback(item)
				end

				if (item.onInstanced) then
					item:onInstanced(index, x, y)
				end
			end
		end, "items")
	else
		ErrorNoHalt("[NutScript] Attempt to give an invalid item! ("..(uniqueID or "nil")..")\n")
	end
end

function nut.item.registerInv(invType, w, h)
	nut.item.inventoryTypes[invType] = {w = w, h = h}
end

function nut.item.newInv(owner, invType, callback)
	nut.db.insertTable({
		_invType = invType,
		_charID = owner
	}, function(data, invID)
		local inventory = nut.item.createInv(w, h, invID)

		if (owner > 0) then
			for k, v in ipairs(player.GetAll()) do
				if (v:getChar() and v:getChar():getID() == owner) then
					inventory:setOwner(owner)
					inventory:sync(v)

					break
				end
			end
		end

		if (callback) then
			callback(inventory)
		end
	end, "inventories")
end

function nut.item.load(path, baseID, isBaseItem)
	local uniqueID = path:match("sh_([_%w]+)%.lua")

	if (uniqueID) then
		uniqueID = (isBaseItem and "base_" or "")..uniqueID
		nut.item.register(uniqueID, baseID, isBaseItem, path)
	else
		ErrorNoHalt("[NutScript] Item at '"..path.."' follows invalid naming convention!\n")
	end
end

function nut.item.register(uniqueID, baseID, isBaseItem, path, luaGenerated)
	local meta = FindMetaTable("Item")

	if (uniqueID) then
		ITEM = (isBaseItem and nut.item.base or nut.item.list)[uniqueID] or setmetatable({data = {}}, meta)
			ITEM.uniqueID = uniqueID
			ITEM.base = baseID
			ITEM.isBase = isBaseItem
			ITEM.data = ITEM.data or {}
			ITEM.hooks = ITEM.hooks or {}
			ITEM.functions = ITEM.functions or {}
			ITEM.functions.drop = {
				tip = "dropTip",
				icon = "icon16/world.png",
				onRun = function(item)
					item:transfer()

					return false
				end,
				onCanRun = function(item)
					return !IsValid(item.entity)
				end
			}
			ITEM.functions.take = {
				tip = "takeTip",
				icon = "icon16/box.png",
				onRun = function(item)
					local status, result = item.player:getChar():getInv():add(item.id)

					if (!status) then
						item.player:notify(result)

						return false
					else
						if (item.data) then -- I don't like it but, meh...
							for k, v in pairs(item.data) do
								item:setData(k, v)
							end
						end
					end
				end,
				onCanRun = function(item)
					return IsValid(item.entity)
				end
			}

			if (PLUGIN) then
				ITEM.plugin = PLUGIN.uniqueID
			end

			if (!luaGenerated and path) then
				nut.util.include(path)
			end

			if (ITEM.base) then
				local baseTable = nut.item.base[ITEM.base]

				if (baseTable) then
					for k, v in pairs(baseTable) do
						if (ITEM[k] == nil) then
							ITEM[k] = v
						end

						ITEM.baseTable = baseTable
					end

					local mergeTable = table.Copy(baseTable)
					ITEM = table.Merge(mergeTable, ITEM)
				else
					ErrorNoHalt("[NutScript] Item '"..ITEM.uniqueID.."' has a non-existent base! ("..ITEM.base..")\n")
				end
			end

			ITEM.width = ITEM.width or 1
			ITEM.height = ITEM.height or 1

			if (ITEM.onRegistered) then
				ITEM:onRegistered()
			end

			(isBaseItem and nut.item.base or nut.item.list)[ITEM.uniqueID] = ITEM
		if (luaGenerated) then
			return ITEM
		else
			ITEM = nil
		end
	else
		ErrorNoHalt("[NutScript] You tried to register an item without uniqueID!\n")
	end
end


function nut.item.loadFromDir(directory)
	local files, folders

	files = file.Find(directory.."/base/*.lua", "LUA")

	for k, v in ipairs(files) do
		nut.item.load(directory.."/base/"..v, nil, true)
	end

	files, folders = file.Find(directory.."/*", "LUA")

	for k, v in ipairs(folders) do
		if (v == "base") then
			continue
		end
		
		for k2, v2 in ipairs(file.Find(directory.."/"..v.."/*.lua", "LUA")) do
			nut.item.load(directory.."/"..v .. "/".. v2, "base_"..v)
		end
	end

	for k, v in ipairs(files) do
		nut.item.load(directory.."/"..v)
	end
end

function nut.item.new(uniqueID, id)
	if (nut.item.instances[id]) then
		return nut.item.instances[id]
	end
	
	local stockItem = nut.item.list[uniqueID]

	if (stockItem) then
		local item = setmetatable({data = {}}, {__index = stockItem})
		item.id = id
		item.data = table.Copy(stockItem.data)

		nut.item.instances[id] = item

		return item
	else
		ErrorNoHalt("[NutScript] Attempt to index unknown item '"..uniqueID.."'\n")
	end
end

do
	nut.util.include("nutscript/gamemode/core/meta/sh_inventory.lua")

	function nut.item.createInv(w, h, id)
		local inventory = setmetatable({w = w, h = h, id = id, slots = {}}, FindMetaTable("Inventory"))
			nut.item.inventories[id] = inventory
			
		return inventory
	end

	function nut.item.restoreInv(invID, w, h, callback)
		local inventory = nut.item.createInv(w, h, invID)

		nut.db.query("SELECT _itemID, _uniqueID, _data, _x, _y FROM nut_items WHERE _invID = "..invID, function(data)
			if (data) then
				local slots = {}
				local badItems = {}

				for _, item in ipairs(data) do
					local x, y = tonumber(item._x), tonumber(item._y)
					local itemID = tonumber(item._itemID)
					local data = util.JSONToTable(item._data or "[]")

					if (x and y and itemID) then
						if (x <= w and x > 0 and y <= h and y > 0) then
							local item2 = nut.item.new(item._uniqueID, itemID)

							if (item2) then
								item2.data = table.Merge(item2.data, data or {})
								item2.gridX = x
								item2.gridY = y
								item2.invID = invID
								
								for x2 = 0, item2.width - 1 do
									for y2 = 0, item2.height - 1 do
										slots[x + x2] = slots[x + x2] or {}
										slots[x + x2][y + y2] = item2
									end
								end
							else
								badItems[#badItems + 1] = itemID
							end
						else
							badItems[#badItems + 1] = itemID
						end
					end
				end

				if (#badItems > 0) then
					nut.db.query("DELETE FROM nut_items WHERE _itemID IN ("..table.concat(badItems, ", ")..")")
				end

				inventory.slots = slots
			end

			if (callback) then
				callback(inventory)
			end
		end)
	end

	if (CLIENT) then
		netstream.Hook("inv", function(slots, id, w, h, owner)
			local character

			if (owner) then
				character = nut.char.loaded[owner]
			else
				character = LocalPlayer():getChar()
			end

			if (character) then
				local inventory = nut.item.createInv(w, h, id)
				inventory:setOwner(character:getID())
				inventory.slots = {}

				local x, y
				
				for k, v in ipairs(slots) do
					x, y = v[1], v[2]

					inventory.slots[x] = inventory.slots[x] or {}

					local item = nut.item.new(v[3], v[4])
						item.data = table.Merge(item.data, v[5] or {})
						item.invID = item.invID or id
					inventory.slots[x][y] = item
				end

				character.vars.inv = character.vars.inv or {}

				for k, v in ipairs(character:getInv(true)) do
					if (v:getID() == id) then
						character:getInv(true)[k] = inventory

						return
					end
				end

				table.insert(character.vars.inv, inventory)
			end
		end)

		netstream.Hook("invData", function(id, key, value)
			local item = nut.item.instances[id]

			if (item) then
				item.data[key] = value

				local panel = item.invID and nut.gui["inv"..item.invID] or nut.gui.inv1

				if (panel and panel.panels) then
					local icon = panel.panels[id]
					icon:SetToolTip("Item #"..item.id.."\n"..L("itemInfo", item.name, (type(item.desc) == "function" and item.desc(item) or item.desc)))
				end
			end
		end)

		netstream.Hook("invSet", function(invID, x, y, uniqueID, id, owner)
			local character = LocalPlayer():getChar()

			if (owner) then
				character = nut.char.loaded[owner]
			end

			if (character) then
				local inventory = nut.item.inventories[invID]

				if (inventory) then
					local item = uniqueID and id and nut.item.new(uniqueID, id) or nil
					item.invID = invID

					inventory.slots[x] = inventory.slots[x] or {}
					inventory.slots[x][y] = item

					local panel = nut.gui["inv"..invID]

					if (IsValid(panel)) then
						local icon = panel:addIcon(item.model or "models/props_junk/popcan01a.mdl", x, y, item.width, item.height)

						if (IsValid(icon)) then
							icon:SetToolTip("Item #"..item.id.."\n"..L("itemInfo", item.name, item.desc))

							panel.panels[item.id] = icon
						end
					end
				end
			end
		end)
		
		netstream.Hook("invMv", function(invID, itemID, x, y)
			local inventory = nut.item.inventories[invID]
			local panel = nut.gui["inv"..invID]

			if (inventory and IsValid(panel)) then
				local icon = panel.panels[itemID]

				if (IsValid(icon)) then
					icon:move({x2 = x, y2 = y}, panel, true)
				end
			end
		end)

		netstream.Hook("invRm", function(id, invID, owner)
			local character = LocalPlayer():getChar()

			if (owner) then
				character = nut.char.loaded[owner]
			end

			if (character) then
				local inventory = nut.item.inventories[invID]

				if (inventory) then
					inventory:remove(id)

					local panel = nut.gui["inv"..invID]

					if (IsValid(panel)) then
						local icon = panel.panels[id]

						if (IsValid(icon)) then
							for k, v in ipairs(icon.slots or {}) do
								if (v.item == icon) then
									v.item = nil
								end
							end

							icon:Remove()
						end
					end
				end
			end			
		end)
	else
		netstream.Hook("invMv", function(client, oldX, oldY, x, y, invID, newInvID)
			oldX, oldY, x, y, invID = tonumber(oldX), tonumber(oldY), tonumber(x), tonumber(y), tonumber(invID)
			if (!oldX or !oldY or !x or !y or !invID) then return end

			local character = client:getChar()

			if (character) then
				local inventory = nut.item.inventories[invID]

				if (inventory and !inventory.owner or (inventory.owner and inventory.owner == character:getID())) then
					local item = inventory:getItemAt(oldX, oldY)

					if (item) then
						if (newInvID and invID != newInvID) then
							local inventory2 = nut.item.inventories[newInvID]

							if (inventory2) then
								item:transfer(newInvID, x, y, client)
							end

							return
						end

						if (inventory:canItemFit(x, y, item.width, item.height, item)) then
							item.gridX = x
							item.gridY = y

							for x2 = 0, item.width - 1 do
								for y2 = 0, item.height - 1 do
									local oldX = inventory.slots[oldX + x2]

									if (oldX) then
										oldX[oldY + y2] = nil
									end
								end
							end

							for x2 = 0, item.width - 1 do
								for y2 = 0, item.height - 1 do
									inventory.slots[x + x2] = inventory.slots[x + x2] or {}
									inventory.slots[x + x2][y + y2] = item
								end
							end

							local receiver = inventory:getReceiver()

							if (receiver and type(receiver) == "table") then
								PrintTable(receiver)
							end
							if (receiver and type(receiver) == "table") then
								for k, v in ipairs(receiver) do
									if (v != client) then
										print(v, x, y)
										netstream.Start(v, "invMv", invID, item:getID(), x, y)
									end
								end
							end

							nut.db.query("UPDATE nut_items SET _x = "..x..", _y = "..y.." WHERE _itemID = "..item.id)
						end
					end
				end
			end
		end)

		netstream.Hook("invAct", function(client, action, item, invID)
			local character = client:getChar()

			if (!character) then
				return
			end

			local inventory = nut.item.inventories[invID]

			if (type(item) != "Entity") then
				if (!inventory or !inventory.owner or inventory.owner != character:getID()) then
					return
				end
			end

			if (hook.Run("CanPlayerInteractItem", client, action, item) == false) then
				return
			end

			if (type(item) == "Entity") then
				if (IsValid(item)) then
					local entity = item
					local itemID = item.nutItemID
					item = nut.item.instances[itemID]

					if (!item) then
						return
					end

					item.entity = entity
					item.player = client
				else
					return
				end
			elseif (type(item) == "number") then
				item = nut.item.instances[item]

				if (!item) then
					return
				end

				item.player = client
			end

			if (item.entity) then
				if (item.entity:GetPos():Distance(client:GetPos()) > 96) then
					return
				end
			elseif (!inventory:getItemByID(item.id)) then
				return
			end

			local callback = item.functions[action]

			if (item.functions[action]) then
				if (callback.onCanRun and callback.onCanRun(item) == false) then
					item.entity = nil
					item.player = nil

					return
				end

				if (callback.onRun(item) != false) then
					if (item.entity) then
						item.entity.nutIsSafe = true
						item.entity:Remove()
					else
						inventory:remove(item.id, nil, true)
						nut.db.query("UPDATE nut_items SET _invID = 0 WHERE _itemID = "..item.id)
					end
				end

				if (item.hooks[action]) then
					item.hooks[action](item)
				end

				item.entity = nil
				item.player = nil
			end
		end)
	end
end

nut.char.registerVar("inv", {
	noNetworking = true,
	noDisplay = true,
	onGet = function(character, index)
		if (index and type(index) != "number") then
			return character.vars.inv or {}
		end

		return character.vars.inv and character.vars.inv[index or 1]
	end
})
