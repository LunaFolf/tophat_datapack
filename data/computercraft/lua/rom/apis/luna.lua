local function getTypeColor(value)
    local typeColor = {
        ["string"] = colors.white,
        ["number"] = colors.yellow,
        ["boolean"] = colors.green,
        ["table"] = colors.purple,
        ["function"] = colors.lightBlue,
        ["nil"] = colors.red,
        ["thread"] = colors.orange,
        ["userdata"] = colors.gray
    }

    return typeColor[type(value)] or colors.white
end

-- Given a table, print it out in JSON format. Either Array or Object format will be used depending on the table.
-- If the terminal supports colors, the type of each value will be printed in a different color.
-- @param table The table to print.
-- @param indent The number of spaces to indent each line. Defaults to 2.
local function printTable(table, indent)
    indent = indent or 2

    local function printTableInternal(table, indent, indentLevel)
        local indentString = string.rep(" ", indentLevel * indent)
        local indentStringNext = string.rep(" ", (indentLevel + 1) * indent)

        local color = term.isColor() and getTypeColor(table) or getTypeColor("table")

        if type(table) == "table" then
            if #table > 0 then
                term.setTextColor(color)
                print(indentString .. "[")
                for i, v in ipairs(table) do
                    if type(v) == "table" then
                        print(indentStringNext .. "{")
                        printTableInternal(v, indent, indentLevel + 2)
                        print(indentStringNext .. "},")
                    else
                        term.setTextColor(getTypeColor(v))
                        print(indentStringNext .. tostring(v) .. ",")
                    end
                end
                term.setTextColor(color)
                print(indentString .. "],")
            else
                term.setTextColor(color)
                print(indentString .. "{")
                for k, v in pairs(table) do
                    if type(v) == "table" then
                        print(indentStringNext .. tostring(k) .. ": {")
                        printTableInternal(v, indent, indentLevel + 2)
                        print(indentStringNext .. "},")
                    else
                        term.setTextColor(getTypeColor(v))
                        print(indentStringNext .. tostring(k) .. ": " .. tostring(v) .. ",")
                    end
                end
                term.setTextColor(color)
                print(indentString .. "},")
            end
        else
            term.setTextColor(getTypeColor(table))
            print(indentString .. tostring(table) .. ",")
        end
    end

    printTableInternal(table, indent, 0)
end

local function removeFnFromTable(table)
    local newTable = {}

    for k, v in pairs(table) do
        if not type(v) == "function" then
            newTable[k] = v
        else
            newTable[k] = "function"
        end
    end

    return newTable
end


local function fixItemName(item)
    -- Some items names are weird depending on what API we use, this just normalizes it.
    if item.technicalName then
        local displayName = item.name
        item.name = item.technicalName
        item.displayName = displayName
    end

    return item
end

local function getItemsUsingItemStorageAPI (itemStoragePeripheral)
    local items = itemStoragePeripheral.items()
    local inventoryItems = {}

    local peripheralName = peripheral.getName(itemStoragePeripheral)
    local peripheralType = peripheral.getType(itemStoragePeripheral)

    for key, item in pairs(items) do
        if item then
            item = fixItemName(item)

            if (not inventoryItems[item.name]) then
                inventoryItems[item.name] = {
                    ["name"] = item.name,
                    ["technicalName"] = item.technicalName or item.name,
                    ["displayName"] = item.displayName or item.name,
                    ["tags"] = item.tags,
                    ["count"] = item.count,
                    ["slots"] = { key },
                    ["where"] = {
                        ["name"] = peripheralName,
                        ["type"] = peripheralType
                    },
                    ["hasTag"] = function(tag)
                        if item.tags then
                            for _, t in pairs(item.tags) do
                                if t == tag then
                                    return true
                                end
                            end
                        end
                        return false
                    end
                }
            else
                inventoryItems[item.name].count = inventoryItems[item.name].count + item.count
                table.insert(inventoryItems[item.name].slots, key)
            end
        end
    end

    return inventoryItems
end

local function getItemsUsingInventoryAPI (inventoryPeripheral)
    local items = inventoryPeripheral.list()
    local inventoryItems = {}

    local peripheralName = peripheral.getName(inventoryPeripheral)
    local peripheralType = peripheral.getType(inventoryPeripheral)

    for key, item in pairs(items) do

        if item then
            item = inventoryPeripheral.getItemDetail(key) or item
            item = fixItemName(item)

            if (not inventoryItems[item.name]) then
                inventoryItems[item.name] = {
                    ["name"] = item.name,
                    ["technicalName"] = item.technicalName or item.name,
                    ["displayName"] = item.displayName or item.name,
                    ["tags"] = item.tags,
                    ["count"] = item.count,
                    ["slots"] = { key },
                    ["where"] = {
                        ["name"] = peripheralName,
                        ["type"] = peripheralType
                    },
                    ["hasTag"] = function(tag)
                        if item.tags then
                            for _, t in pairs(item.tags) do
                                if t == tag then
                                    return true
                                end
                            end
                        end
                        return false
                    end
                }
            else
                inventoryItems[item.name].count = inventoryItems[item.name].count + item.count
                table.insert(inventoryItems[item.name].slots, key)
            end
        end
    end

    return inventoryItems
end

function tableHasValue(table, value)
    for _, v in pairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

function combineTables(table_a, table_b)
    -- Take the values from table_b, and insert them into table_a.

    for _, v in pairs(table_b) do
        table.insert(table_a, v)
    end

    return table_a
end

function getItems(ignoreInventories, debug)
    ignoreInventories = ignoreInventories or {
        "create:item_vault_0"
    }
    debug = debug == true or false
    local hasInventory = {}
    local items = {}

    hasInventory = {}
    items = {}

    local connectedPeripherals = peripheral.getNames()

    if debug then luna.log("Found " .. #connectedPeripherals .. " peripherals.") end

    for i = 1, #connectedPeripherals do
        local pName = connectedPeripherals[i]

        if not tableHasValue(ignoreInventories, pName) then
            local p = peripheral.wrap(pName)
            if p.items or p.list then
                hasInventory[#hasInventory + 1] = p
            end
        end
    end

    if debug then luna.log("Found " .. #hasInventory .. " inventories.") end

    for _, p in pairs(hasInventory) do
        if (p.items) then
            if debug then luna.log("Using ItemStorage API for " .. peripheral.getName(p)) end
            local inventoryItems = getItemsUsingItemStorageAPI(p)
            items = combineTables(items, inventoryItems)
        elseif (p.list) then
            if debug then luna.log("Using Inventory API for " .. peripheral.getName(p)) end
            local inventoryItems = getItemsUsingInventoryAPI(p)
            items = combineTables(items, inventoryItems)
        end
    end

    return items
end

function formatNumber(number)
    local formatted = number
    while true do  
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k==0) then
            break
        end
    end
    return formatted
end

function log(...)
    local time = os.epoch("utc") / 1000
    local dateStr = os.date("%F", time)
    local timeStr = os.date("%T", time)

    local logFileName = ("logs/" .. dateStr .. ".log")

    local prependStr = "[" .. timeStr .. "] "

    local args = { ... }
    local outputStr = ""

    if term.isColor() then term.setTextColor(colors.blue) end
    term.write(prependStr)
    if term.isColor() then term.setTextColor(colors.white) end
    
    for i = 1, #args do
        local arg = args[i]

        if term.isColor() then
            term.setTextColor(getTypeColor(arg))
        end

        if type(arg) == "table" then
            printTable(arg)
            arg = json.encode(removeFnFromTable(arg))
        else
            if type(arg) == "boolean" then
                arg = arg and "true" or "false"
            elseif type(arg) == "nil" then
                arg = "nil"
            elseif type(arg) == "number" then
                arg = luna.formatNumber(arg)
            end

            -- term.write(arg .. (i < #args and " " or ""))

            local width, height = term.getSize()
            local x, y = term.getCursorPos()

            local availableWidth = width - x + 1

            -- If i is 1, then account for the prependStr
            if i == 1 then
                availableWidth = availableWidth - #prependStr
            end

            if #arg > availableWidth then
                local lines = math.ceil(#arg / availableWidth)
                local line = 1

                while line <= lines do
                    local startIndex = (line - 1) * availableWidth + 1
                    local endIndex = startIndex + availableWidth - 1

                    if line == lines then
                        endIndex = #arg
                    end

                    local lineStr = string.sub(arg, startIndex, endIndex)

                    term.write(lineStr)

                    if line < lines then
                        print("")
                    end

                    line = line + 1
                end
            else
                term.write(arg .. (i < #args and " " or ""))
            end
        end

        outputStr = outputStr .. arg .. (i < #args and " " or "")

        if term.isColor() then term.setTextColor(colors.white) end
    end

    print("")

    local logFile = fs.open(logFileName, "a")

    if type(logFile) == "table" then
        logFile.writeLine("[" .. dateStr .. " " .. timeStr .. "] " .. outputStr)
        logFile.close()
    else
        printError("Failed to open log file: '" .. logFileName .. "'!", logFile)
    end
end

function betweenRange(value, min, max)
    return value >= min and value <= max
end