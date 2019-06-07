-- Record writ item links, inputs, and decisions.
--
-- Operate as a fixed-length queue of the N most recent writs.

local WritWorthy = _G['WritWorthy'] -- defined in WritWorthy_Define.lua

WritWorthy.Log = {}

local Log = WritWorthy.Log

-- Event ---------------------------------------------------------------------
--
-- In earlier days, WritWorthy grouped log records into "events". This function
-- ended the previous  event and started a new one. But as of 2019-06-07,
-- WritWorthy now uses LibDebugLogger and has no use for events.

function Log:StartNewEvent(event_name, ...)
    if self.log_event then
        self:EndEvent()
    end
    local s = string.format(event_name or "--", ...)
    self.log_event = { s }
end

function Log:EndEvent()
    local s = table.concat(self.log_event, "\n.  ")
    self.log_event = nil
    Log.Debug(s)
end

-- Append one value to the current event.
--
-- Deprecated, this API was really designed to put arbitrary Lua values into
-- the old log's Lua table. But this LibDebugLogger adapter just flattens
-- everything to a string, which isn't so great for code that used to write 
-- entire tables to the old log with a single Log:Add(table).
--
function Log:Add(value)
    if not self.log_event then
        self:StartNewEvent()
    end
    table.insert(self.log_event, Log:ToString(value))
end

function Log:ToString(value)
    if type(value) ~= "table" then
        return tostring(value)
    end

    local max_line_len = 0
    local lines        = {}
    local sorted_keys  = {}
    for k,v in pairs(value) do
        table.insert(sorted_keys, k)
    end
    table.sort(sorted_keys)
    for _,k in ipairs(sorted_keys) do
        local v    = value[k]
        local line = string.format("%s:%s",tostring(k), tostring(v))
        max_line_len = math.max(max_line_len, #line)
        table.insert(lines, line)
    end
                        -- Short enough to squeeze onto a single line?
                        -- Please do. The log is already way too long.
    if #lines < 10 and max_line_len < 40 then
        return table.concat(lines, "  ")
    end
                        -- Too long for one line. Return as lines.
    return table.concat(lines,"\n")
end

-- LibDebugLogger ------------------------------------------------------------

-- If Sirinsidiator's LibDebugLogger is installed, then return a logger from
-- that. If not, return a NOP replacement.

local NOP = {}
function NOP:Debug(...) end
function NOP:Info(...) end
function NOP:Warn(...) end
function NOP:Error(...) end

WritWorthy.log_to_chat = false

function WritWorthy.Logger()
    local self = WritWorthy
    if not self.logger then
        if LibDebugLogger then
            self.logger = LibDebugLogger.Create(self.name)
        end
        if not self.logger then
            self.logger = NOP
        end
    end
    return self.logger
end

function WritWorthy.LogOne(color, ...)
    if WritWorthy.log_to_chat then
        d("|c"..color..WritWorthy.name..": "..string.format(...).."|r")
    end
end

function Log.Debug(...)
    WritWorthy.LogOne("666666",...)
    WritWorthy.Logger():Debug(...)
end

function Log.Info(...)
    WritWorthy.LogOne("999999",...)
    WritWorthy.Logger():Info(...)
end

function Log.Warn(...)
    WritWorthy.LogOne("FF8800",...)
    WritWorthy.Logger():Warn(...)
end

function Log.Error(...)
    WritWorthy.LogOne("FF6666",...)
    WritWorthy.Logger():Error(...)
end
