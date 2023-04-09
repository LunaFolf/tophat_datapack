local inventories = dofile("rom/modules/main/luna/inventories.lua")
local logger = dofile("rom/modules/main/luna/logger.lua")

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

function getItems(opts)
    return inventories.getIndexedItems(opts)
end

function getTotalItems(opts)
    return inventories.getItemTotals(opts)
end

function betweenRange(value, min, max)
    return value >= min and value <= max
end

function log(...)
    logger.log(...)
end

function error(...)
    logger.error(...)
end

function hasTags(item, tags)
    return inventories.hasTags(item, tags)
end

function inventoryHasSpace(inventoryName, item)
    return inventories.inventoryHasSpace(inventoryName, item)
end