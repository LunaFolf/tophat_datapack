--- Utility commands for logging.
--
-- @module luna.inventories

local expect = dofile("rom/modules/main/cc/expect.lua")
local expect, field = expect.expect, expect.field
local wrap = dofile("rom/modules/main/cc/strings.lua").wrap

local function preLogFileCheck()
  local dateStr = os.date("%F")
  -- Create the logs directory if it doesn't exist.
  if not fs.exists("logs") then
      fs.makeDir("logs")
  end

  -- Create the log file for today if it doesn't exist.
  if not fs.exists("logs/" .. dateStr .. ".log") then
      local file = fs.open("logs/" .. dateStr .. ".log", "w")
      if file then
        file.close()
      else
        printError("Failed to create log file: " .. dateStr .. ".log")
      end
  end
end

preLogFileCheck()

local function getTypeColor(value, logType)
  local defaultColor = colors.white
  if logType == "error" then
    defaultColor = colors.red
  end

    local typeColor = {
        ["string"] = defaultColor,
        ["number"] = colors.yellow,
        ["boolean"] = colors.green,
        ["table"] = colors.purple,
        ["function"] = colors.lightBlue,
        ["nil"] = colors.red,
        ["thread"] = colors.orange,
        ["userdata"] = colors.gray
    }

    return typeColor[type(value)] or defaultColor
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



local function log_impl ( args, opts )
  expect(1, args, "table")
  expect(2, opts, "table", "nil")

  if opts then
    field(opts, "type", "string")
  end

  local logType = opts.type or "info"

  local time = os.epoch("utc") / 1000
  local dateStr = os.date("%F", time)
  local timeStr = os.date("%T", time)

  preLogFileCheck()

  local logFileName = ("logs/" .. dateStr .. ".log")
  local prependStr = ("[" .. timeStr .. "] ")
  local outputStr = ""

  local defaultColor = colors.white
  if logType == "error" then
    defaultColor = colors.red
  end

  if term.isColor() then term.setTextColor(colors.blue) end
  term.write(prependStr)
  if term.isColor() then term.setTextColor(defaultColor) end

  for index, arg in ipairs(args) do
    if term.isColor() then
      term.setTextColor(getTypeColor(arg, logType))
    end

    if type(arg) == "table" then
      printTable(arg)
      arg = json.encode(removeFnFromTable(arg))
    else
      local lines = wrap(tostring(arg) or "ERR")
      for _, line in ipairs(lines) do
        print(line)
      end
    end

    outputStr = outputStr .. tostring(arg) .. " "
  end

  if term.isColor() then term.setTextColor(colors.white) end -- Intentionally not using defaultColor here, so we can reset the color for other prints.

  local file = fs.open(logFileName, "a")

  if type(file) == "table" then
    file.writeLine(prependStr .. outputStr)
    file.close()
  else
    printError("Failed to open log file: " .. logFileName, logFileName)
  end
end

local function log ( ... )
  local args = { ... }
  
  log_impl(args, { ["type"] = "info" })
end

local function error ( ... )
  local args = { ... }
  
  log_impl(args, { ["type"] = "error" })
end

return setmetatable({
  log = log,
  error = error
}, { __call = function ( self, ... ) return self.log(...) end })