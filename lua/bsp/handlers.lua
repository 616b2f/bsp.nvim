local protocol = require('bsp.protocol')
local console = require('bsp.bsp-console')
local ms = protocol.Methods
local api = vim.api


local ns = vim.api.nvim_create_namespace("bsp")

local M = {}

--- Writes to error buffer.
---@param ... string Will be concatenated before being written
local function err_message(...)
  local message = vim.iter({ ... }):flatten():totable():concat()
  vim.notify(message, vim.log.levels.ERROR)
  api.nvim_command('redraw')
end

--- Writes to BSP console buffer
---@param client_name string Name of the client
---@param client_id integer ID of the client
---@param eventtime integer? Time when the event happened
---@param data string Will be concatenated before being written
local function write_to_console_with_time(client_name, client_id, eventtime, data)
  local time = '0000000000000'
  if eventtime then
    time = tostring(eventtime)
  end
  local message = string.format('[bsp:%s(id=%s)] %s: %s', client_name, tostring(client_id), time, string.gsub(data, '\n', ''))
  console.write({message})
end

--- Writes to BSP console buffer
---@param client_name string Name of the client
---@param client_id integer ID of the client
---@param data string Will be concatenated before being written
local function write_to_console(client_name, client_id, data)
  local message = string.format('[bsp:%s(id=%s)] %s', client_name, tostring(client_id), string.gsub(data, '\n', ''))
  console.write({message})
end

local errlist_type_map = {
  [vim.diagnostic.severity.ERROR] = 'E',
  [vim.diagnostic.severity.WARN] = 'W',
  [vim.diagnostic.severity.INFO] = 'I',
  [vim.diagnostic.severity.HINT] = 'N',
}

--- Convert a list of diagnostics to a list of quickfix items that can be
--- passed to |setqflist()| or |setloclist()|.
---
---@param filename string Filename that is the scope of the diagnostics
---@param diagnostics lsp.Diagnostic[] List of diagnostics.
---@param build_target string BuildTarget URI
---@param encoding any
---@return table[] of quickfix list items |setqflist-what|
local function diagnostic_lsp_to_toqflist(filename, build_target, diagnostics, encoding)
  vim.validate({
    diagnostics = {
      diagnostics,
      vim.islist,
      'a list of diagnostics',
    },
  })

  ---@param lnum integer
  ---@param col integer
  ---@param offset_encoding string
  ---@return integer
  local function line_byte_from_position(lnum, col, offset_encoding)
    if offset_encoding == 'utf-8' then
      return col
    end

    local ok, result = pcall(vim.str_byteindex, lnum, col, offset_encoding == 'utf-16')
    if ok then
      return result --- @type integer
    end

    return col
  end

  local offset_encoding = encoding or 'utf-16'

  --- @param diagnostic lsp.Diagnostic
  local list = vim.tbl_map(function(diagnostic)
    local start = diagnostic.range.start
    local start_line = start.line + 1
    local start_character = start.character and start.character + 1 or nil
    local _end = diagnostic.range['end']
    local _end_line = _end.line and _end.line + 1 or nil
    local _end_character = _end.character and _end.character + 1 or nil
    return {
      lnum = start_line,
      col = line_byte_from_position(start_line, start_character, offset_encoding),
      end_lnum = _end_line,
      end_col = line_byte_from_position(_end_line, _end_character, offset_encoding),
      type = diagnostic.severity and errlist_type_map[diagnostic.severity] or 'E',
      text = diagnostic.message,
      source = diagnostic.source,
      filename = filename:gsub("^file://", ""),
      code = diagnostic.code,
      vcol = 1,
      namespace = ns,
      user_data = {
        text_document = filename,
        build_target = build_target
      }
    }
  end, diagnostics)

  table.sort(list, function(a, b)
    if a.bufnr == b.bufnr then
      if a.lnum == b.lnum then
        return a.col < b.col
      else
        return a.lnum < b.lnum
      end
    else
      return a.bufnr < b.bufnr
    end
  end)
  return list
end

-- M[ms.workspace_buildTargets] = function(_, result, ctx)
--   local bsp = require('bsp')
--   local client = bsp.get_client_by_id(ctx.client_id)
--   if not client then
--     err_message('BSP[id=', tostring(ctx.client_id), '] client has shut down during progress update')
--     return vim.NIL
--   end
--
--   for _, target in ipairs(result.targets) do
--     client.build_targets[target.id.uri] = target
--   end
-- end


--see: https://build-server-protocol.github.io/docs/specification/#onrunprintstdout-notification
---@param result bsp.PrintParams
---@param ctx bsp.HandlerContext
M[ms.run_printStdout] = function(_, result, ctx)
  local bsp = require('bsp')
  local client = bsp.get_client_by_id(ctx.client_id)
  if not client then
    err_message('BSP[id=', tostring(ctx.client_id), '] client has shut down during progress update')
    return vim.NIL
  end

  write_to_console(client.name, ctx.client_id, vim.inspect(result))
end

--see: https://build-server-protocol.github.io/docs/specification/#onrunprintstderr-notification
---@param result bsp.PrintParams
---@param ctx bsp.HandlerContext
M[ms.run_printStderr] = function(_, result, ctx)
  local bsp = require('bsp')
  local client = bsp.get_client_by_id(ctx.client_id)
  if not client then
    err_message('BSP[id=', tostring(ctx.client_id), '] client has shut down during progress update')
    return vim.NIL
  end

  write_to_console(client.name, ctx.client_id, vim.inspect(result))
end

--see: https://build-server-protocol.github.io/docs/specification/#onbuildlogmessage-notification
---@param result bsp.LogMessageParams
---@param ctx bsp.HandlerContext
M[ms.build_logMessage] = function(_, result, ctx)
  local bsp = require('bsp')
  local client = bsp.get_client_by_id(ctx.client_id)
  if not client then
    err_message('BSP[id=', tostring(ctx.client_id), '] client has shut down during progress update')
    return vim.NIL
  end

  write_to_console(client.name, ctx.client_id, vim.inspect(result))
end

--see: https://build-server-protocol.github.io/docs/specification/#onbuildpublishdiagnostics-notification
---@param result bsp.PublishDiagnosticsParams
 --@param ctx bsp.HandlerContext
M[ms.build_publishDiagnostics] = function(_, result, ctx)
  local bsp = require('bsp')
  local client = bsp.get_client_by_id(ctx.client_id)
  if not client then
    err_message('BSP[id=', tostring(ctx.client_id), '] client has shut down during progress update')
    return vim.NIL
  end

  vim.schedule(function ()

    if result.reset and result.textDocument.uri == "/" and result.buildTarget.uri == "/" then
      vim.fn.setqflist({}, 'r', {title = "bsp-diagnostics"})
      return
    end

    local diagnostics = diagnostic_lsp_to_toqflist(result.textDocument.uri, result.buildTarget.uri, result.diagnostics, client.offset_encoding)

    local qflist = vim.fn.getqflist({title = "bsp-diagnostics", items = 0 })

    if result.reset then
      if next(qflist.items) ~= nil then
        qflist.items = vim.iter(qflist.items)
          :filter(function (item)
            if item.user_data and item.user_data.text_document == result.textDocument.uri and item.user_data.build_target == result.buildTarget.uri then
              return false
            end
            return true
          end)
          :totable()
      end

      for _, diag in pairs(diagnostics) do
        table.insert(qflist.items, diag)
      end
      vim.fn.setqflist({}, 'r', qflist)
    else
      for _, diag in pairs(diagnostics) do
        table.insert(qflist.items, diag)
      end
      -- vim.fn.setqflist({}, 'r', qflist)
      vim.fn.setqflist({}, 'a', {
        title = "bsp-diagnostics",
        items = diagnostics
      })
    end

    if next(qflist.items) ~= nil then
      vim.cmd('copen')
    else
      vim.cmd('cclose')
    end
  end)
end

--see: https://build-server-protocol.github.io/docs/specification/#onbuildshowmessage-notification
---@param result bsp.ShowMessageParams
---@param ctx bsp.HandlerContext
M[ms.build_showMessage] = function(_, result, ctx)
  local bsp = require('bsp')
  local client = bsp.get_client_by_id(ctx.client_id)
  if not client then
    err_message('BSP[id=', tostring(ctx.client_id), '] client has shut down during progress update')
    return vim.NIL
  end

  write_to_console(client.name, ctx.client_id, vim.inspect(result))
end

--see: https://build-server-protocol.github.io/docs/specification/#onbuildtargetdidchange-notification
---@param result bsp.DidChangeBuildTarget
---@param ctx bsp.HandlerContext
M[ms.buildTarget_didChange] = function(_, result, ctx)
  local bsp = require('bsp')
  local client = bsp.get_client_by_id(ctx.client_id)
  if not client then
    err_message('BSP[id=', tostring(ctx.client_id), '] client has shut down during progress update')
    return vim.NIL
  end

  for _, change in ipairs(result.changes) do
    if change.kind == protocol.BuildTargetEventKind.Deleted then
      client.build_targets[change.target.uri] = nil
    else
      --TODO: see how to implement correctly
      -- local request_success, request_id = client.request(ms.workspace_buildTargets, nil, nil, 0)
    end

  end
end

--see: https://build-server-protocol.github.io/docs/specification#taskstartparams
---@param result bsp.TaskStartParams
---@param ctx bsp.HandlerContext
M[ms.build_taskStart] = function(_, result, ctx)
  local bsp = require('bsp')
  local client = bsp.get_client_by_id(ctx.client_id)
  if not client then
    err_message('BSP[id=', tostring(ctx.client_id), '] client has shut down during progress update')
    return vim.NIL
  end

  client.progress:push(result)

  vim.schedule(function()
    api.nvim_exec_autocmds('User', {
      pattern = 'BspProgress:start',
      group = bsp.BspGroup,
      modeline = false,
      data = { client_id = ctx.client_id, result = result },
    })
  end)
end

--see: https://build-server-protocol.github.io/docs/specification#onbuildtaskprogress-notification
---@param result bsp.TaskProgressParams
---@param ctx bsp.HandlerContext
M[ms.build_taskProgress] = function(_, result, ctx)
  local bsp = require('bsp')
  local client = bsp.get_client_by_id(ctx.client_id)
  if not client then
    err_message('BSP[id=', tostring(ctx.client_id), '] client has shut down during progress update')
    return vim.NIL
  end

  client.progress:push(result)

  vim.schedule(function()
    api.nvim_exec_autocmds('User', {
      pattern = 'BspProgress:progress',
      group = bsp.BspGroup,
      modeline = false,
      data = { client_id = ctx.client_id, result = result },
    })
  end)
end

--see: https://build-server-protocol.github.io/docs/specification#onbuildtaskprogress-notification
---@param result bsp.TaskFinishParams
---@param ctx bsp.HandlerContext
M[ms.build_taskFinish] = function(_, result, ctx)
  local bsp = require('bsp')
  local client = bsp.get_client_by_id(ctx.client_id)
  if not client then
    err_message('BSP[id=', tostring(ctx.client_id), '] client has shut down during progress update')
    return vim.NIL
  end

  client.progress:push(result)

  vim.schedule(function()
    api.nvim_exec_autocmds('User', {
      pattern = 'BspProgress:finish',
      group = bsp.BspGroup,
      modeline = false,
      data = { client_id = ctx.client_id, result = result },
    })
  end)
end

return M
