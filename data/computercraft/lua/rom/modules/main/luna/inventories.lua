--- Utility commands for interacting with inventories.
--
-- @module luna.inventories

local expect = dofile("rom/modules/main/cc/expect.lua")
local expect, field = expect.expect, expect.field

local cachedInventories = {}
local cachedTypes = {}

local fixItemName = function ( item )
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
    ["tags"] = item.tags,
    ["count"] = item.count
  }
end

function getInventoryItems ( inventoryPeripheral )
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
      mappedItem.slots = { slotIndex }

      if not inventoryItems[mappedItem.name] then
        mappedItem.where = peripheral.getName(inventoryPeripheral)
        inventoryItems[mappedItem.name] = mappedItem
      else
        inventoryItems[mappedItem.name].count = inventoryItems[mappedItem.name].count + mappedItem.count
        table.insert(inventoryItems[mappedItem.name].slots, mappedItem.slots[1])
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

function getIndexedItems ( opts )
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

function getItemTotals ( opts )
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

return setmetatable({
  getIndexedItems = getIndexedItems,
  getItemTotals = getItemTotals
}, { __call = function ( _, ... ) return getIndexedItems(...) end })