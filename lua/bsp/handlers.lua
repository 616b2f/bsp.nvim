local protocol = require('bsp.protocol')
local console = require('bsp.bsp-console')
local ms = protocol.Methods
local api = vim.api

local M = {}

local namespace = vim.api.nvim_create_namespace('bsp')

--- Writes to error buffer.
---@param ... string Will be concatenated before being written
local function err_message(...)
  vim.notify(table.concat(vim.tbl_flatten({ ... })), vim.log.levels.ERROR)
  api.nvim_command('redraw')
end

--- Writes to BSP console buffer
---@param client_id integer ID of the client
---@param eventtime integer? Time when the event happened
---@param data string Will be concatenated before being written
local function write_to_console_with_time(client_id, eventtime, data)
  local time = '0000000000000'
  if eventtime then
    time = tostring(eventtime)
  end
  local message = 'BSP[id=' .. tostring(client_id) .. '] ' .. time .. ': ' .. string.gsub(data, '\n', '')
  console.write({message})
end

--- Writes to BSP console buffer
---@param client_id integer ID of the client
---@param data string Will be concatenated before being written
local function write_to_console(client_id, data)
  local message = 'BSP[id=' .. tostring(client_id) .. '] ' .. string.gsub(data, '\n', '')
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
---@param diagnostics lsp.Diagnostic[] List of diagnostics |bsp-diagnostic|.
---@return table[] of quickfix list items |setqflist-what|
local function toqflist(filename, diagnostics)
  vim.validate({
    diagnostics = {
      diagnostics,
      vim.tbl_islist,
      'a list of diagnostics',
    },
  })

  local list = {}
  for _, v in ipairs(diagnostics) do
    local item = {
      filename = filename,
      lnum = v.range.start.line + 1,
      col = v.range.start.character and (v.range.start.character + 1) or nil,
      end_lnum = v.range["end"].line and (v.range["end"].character + 1) or nil,
      end_col = v.range["end"].character and (v.range["end"].character + 1) or nil,
      text = v.message,
      type = v.severity and errlist_type_map[v.severity] or 'E',
    }
    table.insert(list, item)
  end
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
--   local log = require('bsp.log')
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
  local log = require('bsp.log')
  local client = bsp.get_client_by_id(ctx.client_id)
  if not client then
    err_message('BSP[id=', tostring(ctx.client_id), '] client has shut down during progress update')
    return vim.NIL
  end

  write_to_console(ctx.client_id, result.task.id, vim.inspect(result))
end

--see: https://build-server-protocol.github.io/docs/specification/#onrunprintstderr-notification
---@param result bsp.PrintParams
---@param ctx bsp.HandlerContext
M[ms.run_printStderr] = function(_, result, ctx)
  local bsp = require('bsp')
  local log = require('bsp.log')
  local client = bsp.get_client_by_id(ctx.client_id)
  if not client then
    err_message('BSP[id=', tostring(ctx.client_id), '] client has shut down during progress update')
    return vim.NIL
  end

  write_to_console(ctx.client_id, vim.inspect(result))
end

--see: https://build-server-protocol.github.io/docs/specification/#onbuildlogmessage-notification
---@param result bsp.LogMessageParams
---@param ctx bsp.HandlerContext
M[ms.build_logMessage] = function(_, result, ctx)
  local bsp = require('bsp')
  local log = require('bsp.log')
  local client = bsp.get_client_by_id(ctx.client_id)
  if not client then
    err_message('BSP[id=', tostring(ctx.client_id), '] client has shut down during progress update')
    return vim.NIL
  end

  write_to_console(ctx.client_id, vim.inspect(result))
end

--see: https://build-server-protocol.github.io/docs/specification/#onbuildpublishdiagnostics-notification
---@param result bsp.PublishDiagnosticsParams
 --@param ctx bsp.HandlerContext
M[ms.build_publishDiagnostics] = function(_, result, ctx)
  local bsp = require('bsp')
  local log = require('bsp.log')
  local client = bsp.get_client_by_id(ctx.client_id)
  if not client then
    err_message('BSP[id=', tostring(ctx.client_id), '] client has shut down during progress update')
    return vim.NIL
  end

  local diagnostics = toqflist(result.textDocument.uri, result.diagnostics)
  if result.reset then
    vim.fn.setqflist({}, 'r')
  else
    vim.fn.setqflist({}, 'a', {
      title = "bsp-diagnostics",
      items = diagnostics
    })
    vim.cmd('copen')
  end
end

--see: https://build-server-protocol.github.io/docs/specification/#onbuildshowmessage-notification
---@param result bsp.ShowMessageParams
---@param ctx bsp.HandlerContext
M[ms.build_showMessage] = function(_, result, ctx)
  local bsp = require('bsp')
  local log = require('bsp.log')
  local client = bsp.get_client_by_id(ctx.client_id)
  if not client then
    err_message('BSP[id=', tostring(ctx.client_id), '] client has shut down during progress update')
    return vim.NIL
  end

  write_to_console(ctx.client_id, vim.inspect(result))
end

--see: https://build-server-protocol.github.io/docs/specification/#onbuildtargetdidchange-notification
---@param result bsp.DidChangeBuildTarget
---@param ctx bsp.HandlerContext
M[ms.buildTarget_didChange] = function(_, result, ctx)
  local bsp = require('bsp')
  local log = require('bsp.log')
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

  api.nvim_exec_autocmds('User', {
    pattern = 'BspProgress:start',
    group = bsp.BspGroup,
    modeline = false,
    data = { client_id = ctx.client_id, result = result },
  })
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

  api.nvim_exec_autocmds('User', {
    pattern = 'BspProgress:progress',
    group = bsp.BspGroup,
    modeline = false,
    data = { client_id = ctx.client_id, result = result },
  })
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

  api.nvim_exec_autocmds('User', {
    pattern = 'BspProgress:finish',
    group = bsp.BspGroup,
    modeline = false,
    data = { client_id = ctx.client_id, result = result },
  })
end

return M
