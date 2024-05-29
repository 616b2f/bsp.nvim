local log = {}

--- Log level dictionary with reverse lookup as well.
---
--- Can be used to lookup the number from the name or the name from the number.
--- Levels by name: "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "OFF"
--- Level numbers begin with "TRACE" at 0
--- @nodoc
local levels = vim.deepcopy(vim.log.levels)

-- This is put here on purpose after the loop above so that it doesn't
-- interfere with iterating the levels
if vim.version().minor >= 11 then
  for k, v in pairs(levels) do
    levels[v] = k
  end
else
  vim.tbl_add_reverse_lookup(levels)
end

-- Default log level is warn.
local current_log_level = levels.WARN

local log_date_format = '%F %H:%M:%S'

local format_func = function(arg)
  return vim.inspect(arg, { newline = '' })
end

-- Create a logger for base protocol based client.
---@param category string Category to which the logs belong.
---@return Logger
function log.new_logger(category)
  ---@class Logger
  ---@field trace fun(...: string|table|nil)
  ---@field debug fun(...: string|table|nil)
  ---@field info fun(...: string|table|nil)
  ---@field warn fun(...: string|table|nil)
  ---@field error fun(...: string|table|nil)
  ---@field category string Category to which the log messages should go
  local logger = {
    category = category
  }

  for level, levelnr in pairs(levels) do
    -- Set the lowercase name as the main use function.
    -- If called without arguments, it will check whether the log level is
    -- greater than or equal to this one. When called with arguments, it will
    -- log at that level (if applicable, it is checked either way).
    --
    -- Recommended usage:
    -- ```
    -- local _ = logger.warn() and logger.warn("123")
    -- ```
    --
    -- This way you can avoid string allocations if the log level isn't high enough.
    if type(level) == 'string' and level ~= 'OFF' then
      logger[level:lower()] = function(...)
        local argc = select('#', ...)
        if levelnr < current_log_level then
          return false
        end
        if argc == 0 then
          return true
        end
        local info = debug.getinfo(2, 'Sl')
        local parts = {}
        for i = 1, argc do
          local arg = select(i, ...)
          if arg == nil then
            table.insert(parts, 'nil')
          else
            table.insert(parts, format_func(arg))
          end
        end
        local message = table.concat(parts, '\t')
        log._write_log(category, level, os.time(), info, message)
      end
    end
  end

  return logger
end

do
  local function notify(msg, level)
    if vim.in_fast_event() then
      vim.schedule(function()
        vim.notify(msg, level)
      end)
    else
      vim.notify(msg, level)
    end
  end

  local path_sep = vim.uv.os_uname().version:match('Windows') and '\\' or '/'
  local function path_join(...)
    return table.concat(vim.tbl_flatten({ ... }), path_sep)
  end
  local logfilename = path_join(vim.fn.stdpath('log'), 'bsp.log')

  -- TODO: Ideally the directory should be created in open_logfile(), right
  -- before opening the log file, but open_logfile() can be called from libuv
  -- callbacks, where using fn.mkdir() is not allowed.
  vim.fn.mkdir(vim.fn.stdpath('log'), 'p')

  --- Returns the log filename.
  ---@return string log filename
  function log.get_filename()
    return logfilename
  end

  local logfile, openerr
  --- Opens log file. Returns true if file is open, false on error
  local function open_logfile()
    -- Try to open file only once
    if logfile then
      return true
    end
    if openerr then
      return false
    end

    logfile, openerr = io.open(logfilename, 'a+')
    if not logfile then
      local err_msg = string.format('Failed to open BSP client log file: %s', openerr)
      notify(err_msg, vim.log.levels.ERROR)
      return false
    end

    local log_info = vim.uv.fs_stat(logfilename)
    if log_info and log_info.size > 1e9 then
      local warn_msg = string.format(
        'BSP client log is large (%d MB): %s',
        log_info.size / (1000 * 1000),
        logfilename
      )
      notify(warn_msg)
    end
    return true
  end

  ---@private format and log to the default sink
  ---@param category string
  ---@param level string
  ---@param timestamp integer
  ---@param info debuginfo
  ---@param message string
  function log._write_log(category, level, timestamp, info, message)
    if not open_logfile() then
      return false
    end
    local formatted_message = string.format(
      '[%s][%s][%s] ...%s:%s\t%s',
      category,
      level,
      os.date(log_date_format, timestamp),
      string.sub(info.short_src, #info.short_src - 15),
      info.currentline,
      message
    )
    logfile:write(formatted_message, '\n')
    logfile:flush()
  end
end

--- Sets the current log level.
---@param level (string|integer) One of `bp.log.levels`
function log.set_level(level)
  if type(level) == 'string' then
    current_log_level =
      assert(levels[level:upper()], string.format('Invalid log level: %q', level))
  else
    assert(type(level) == 'number', 'level must be a number or string')
    assert(levels[level], string.format('Invalid log level: %d', level))
    current_log_level = level
  end
end

--- Gets the current log level.
---@return integer current log level
function log.get_level()
  return current_log_level
end

--- Sets formatting function used to format logs
---@param handle function function to apply to logging arguments, pass vim.inspect for multi-line formatting
function log.set_format_func(handle)
  assert(handle == vim.inspect or type(handle) == 'function', 'handle must be a function')
  format_func = handle
end

--- Checks whether the level is sufficient for logging.
---@param level integer log level
---@returns (bool) true if would log, false if not
function log.should_log(level)
  return level >= current_log_level
end

return log
