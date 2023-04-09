--- Utility commands for interacting with inventories.
--
-- @module luna.inventories

local expect = dofile("rom/modules/main/cc/expect.lua")
local expect, field = expect.expect, expect.field

local cachedInventories = {}
local cachedTypes = {}

local function fixItemName ( item )
  if item.technicalName then
    item.displayName = item.name
    item.name = item.technicalName
  end

  return item
end

local function mapItem ( item )
  item = fixItemName(item)

  return {
    ["name"] = item.name,
    ["technicalName"] = item.technicalName or item.name,
    ["displayName"] = item.displayName or item.name,
    ["tags"] = tags,
    ["count"] = item.count,
    ["maxCount"] = item.maxCount or 1 -- Try to find a way to ALWAYS get the max count.
  }
end

local function getInventoryItems ( inventoryPeripheral )
  local items = {}

  if inventoryPeripheral.list then
    items = inventoryPeripheral.list()
  elseif inventoryPeripheral.items then
    items = inventoryPeripheral.items()
  end

  local inventoryItems = {}

  for slotIndex, item in pairs(items) do
    if item then
      if inventoryPeripheral.getItemDetail then
        item = inventoryPeripheral.getItemDetail(slotIndex) or item
      end
      local mappedItem = mapItem(item)

      if not inventoryItems[mappedItem.name] then
        mappedItem.where = peripheral.getName(inventoryPeripheral)
        inventoryItems[mappedItem.name] = mappedItem
        mappedItem.slots = { tostring(slotIndex) }
      else
        inventoryItems[mappedItem.name].count = inventoryItems[mappedItem.name].count + mappedItem.count
        table.insert(inventoryItems[mappedItem.name].slots, tostring(slotIndex))
      end
    end
  end

  -- Convert the hash table to an array.
  local inventoryItemsArray = {}
  for name, item in pairs(inventoryItems) do
    table.insert(inventoryItemsArray, item)
  end

  -- Sort the array by item.count, descending.
  table.sort(inventoryItemsArray, function ( a, b )
    return a.count > b.count
  end)

  return inventoryItemsArray
end

local function getIndexedItems ( opts )
  expect(1, opts, "table", "nil")

  if opts then
    field(opts, "inventories", "table", "nil")
    field(opts, "ignoreInventories", "table", "nil")
    field(opts, "debug", "boolean", "nil")
  end

  local debug = opts and opts.debug or false
  local ignoreInventories = opts and opts.ignoreInventories or {}

  -- Convert ignoreInventories to a hash table for faster lookup.
  if ignoreInventories then
    local temp = {}
    for index = 1, #ignoreInventories do
      temp[ignoreInventories[index]] = true
    end

    ignoreInventories = temp
  end

  -- Add left, right, back, front, top, bottom to the ignore list.
  for _, side in ipairs({ "left", "right", "back", "front", "top", "bottom" }) do
    if peripheral.isPresent(side) then
      ignoreInventories[side] = true
    end
  end

  local items = {}

  local connectedPeripherals = opts and opts.inventories or peripheral.getNames()

  if debug then luna.log("Found " .. #connectedPeripherals .. " peripherals.") end

  for index = 1, #connectedPeripherals do
    local peripheralName = connectedPeripherals[index]

    if not ignoreInventories[peripheralName] then
      local types = cachedTypes[peripheralName]
      if not types then
        types = { peripheral.getType(peripheralName) }
        cachedTypes[peripheralName] = types
      end

      local inventoryPeripheral = cachedInventories[peripheralName]
      if not inventoryPeripheral then
        inventoryPeripheral = peripheral.wrap(peripheralName)
        cachedInventories[peripheralName] = inventoryPeripheral
      end

      local isInventory = false

      for index = 1, #types do
        if types[index] == "inventory" or types[index] == "item_storage" then
          isInventory = true
          break
        end

        -- Check for the presence of the list() or items() methods, because some mods are dumb.
        if inventoryPeripheral.list then
          isInventory = true
          cachedTypes[peripheralName] = { "inventory" }
          break
        elseif inventoryPeripheral.items then
          isInventory = true
          cachedTypes[peripheralName] = { "item_storage" }
          break
        end
      end

      if isInventory then
        if debug then luna.log("Found inventory: " .. peripheralName) end

        local inventoryItems = getInventoryItems(inventoryPeripheral)

        for index, item in ipairs(inventoryItems) do
          table.insert(items, item)
        end

      end
    end

  end

  -- Sort the array by item.count, descending.
  table.sort(items, function ( a, b )
    return a.count > b.count
  end)

  return items
end

local function getItemTotals ( opts )
  local items = getIndexedItems(opts)
  local hashTable = {}

  for index, item in ipairs(items) do
    item.where = nil
    item.slots = nil
    if not hashTable[item.name] then
      hashTable[item.name] = item
    else
      hashTable[item.name].count = hashTable[item.name].count + item.count
    end
  end

  -- Convert the hash table to an array.
  local itemsArray = {}
  for name, item in pairs(hashTable) do
    table.insert(itemsArray, item)
  end

  -- Sort the array by item.count, descending.
  table.sort(itemsArray, function ( a, b )
    return a.count > b.count
  end)

  return itemsArray
end

local function hasTags ( item, tags )
  expect(1, item, "table")
  expect(2, tags, "table", "string")

  if type(tags) == "string" then tags = { tags } end

  if not item.tags then return false end

  -- Return true if all tags are present.
  -- Return false if one or more tags are missing.

  for index = 1, #tags do
    local tag = tags[index]
    if not item.tags[tag] then return false end
  end

  return true
end

-- Given an inventory name, and an optional item table (with name and count), return true if the inventory has space for the item.
-- If no item is given, return true if the inventory has any space.
-- If the inventory is full, return false.
local function inventoryHasSpace ( inventoryName, item )
  expect(1, inventoryName, "string")
  expect(2, item, "table", "nil")

  if item then
    expect(2, item.name, "string")
    expect(2, item.count, "number")
  end

  local items = getIndexedItems({ ["inventories"] = { inventoryName } })

  if item then
    for index = 1, #items do
      if items[index].name == item.name then
        return items[index].count + item.count <= items[index].maxCount
      end
    end

    return item.count <= 64
  else
    for index = 1, #items do
      if items[index].count < items[index].maxCount then
        return true
      end
    end

    return false
  end
end

-- return setmetatable({
--   getIndexedItems = getIndexedItems,
--   getItemTotals = getItemTotals,
--   hasTags = hasTags,
--   inventoryHasSpace = inventoryHasSpace,
-- }, { __call = function ( _, ... ) return getIndexedItems(...) end })

return {
  getIndexedItems = getIndexedItems,
  getItemTotals = getItemTotals,
  hasTags = hasTags,
  inventoryHasSpace = inventoryHasSpace,
}