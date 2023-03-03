--- Utility commands for logging.
--
-- @module luna.inventories

local expect = dofile("rom/modules/main/cc/expect.lua")
local expect, field = expect.expect, expect.field
local wrap = dofile("rom/modules/main/cc/strings.lua").wrap

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

function log ( ... )
  local time = os.epoch("utc") / 1000
  local dateStr = os.date("%F", time)
  local timeStr = os.date("%T", time)

  local logFileName = ("logs/" .. dateStr .. ".log")
  local prependStr = ("[" .. timeStr .. "] ")

  local args = { ... }
  local outputStr = ""

  if term.isColor() then term.setTextColor(colors.blue) end
  term.write(prependStr)
  if term.isColor() then term.setTextColor(colors.white) end

  for index, arg in ipairs(args) do
    if term.isColor() then
      term.setTextColor(getTypeColor(arg))
    end

    if type(arg) == "table" then
      printTable(arg)
      arg = json.encode(removeFnFromTable(arg))
    else
      local lines = wrap(tostring(arg))
      for _, line in ipairs(lines) do
        print(line)
      end
    end

    outputStr = outputStr .. tostring(arg) .. " "
  end

  if term.isColor() then term.setTextColor(colors.white) end

  local file = fs.open(logFileName, "a")

  if type(file) == "table" then
    file.writeLine(prependStr .. outputStr)
    file.close()
  else
    printError("Failed to open log file: " .. logFileName, logFileName)
  end
end

return setmetatable({
  log = log
}, { __call = function ( self, ... ) return self.log(...) end })