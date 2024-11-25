local protocol = require('bsp.protocol')
local console = require('bsp.bsp-console'):new()
local ms = protocol.Methods
local api = vim.api

local run_console = require('bsp.bsp-console'):new({name='[BSP run]'})

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
  console:write({message})
end

--- Writes to BSP console buffer
---@param client_name string Name of the client
---@param client_id integer ID of the client
---@param data string Will be concatenated before being written
local function write_to_console(client_name, client_id, data)
  local message = string.format('[bsp:%s(id=%s)] %s', client_name, tostring(client_id), string.gsub(data, '\n', ''))
  console:write({message})
end

--- Writes to BSP run console buffer
---@param client_name string Name of the client
---@param client_id integer ID of the client
---@param data string Will be concatenated before being written
local function write_to_run_console(client_name, client_id, data)
  local message = string.format('[bsp:%s(id=%s)] %s', client_name, tostring(client_id), string.gsub(data, '\n', ''))
  run_console:write({message})
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
---@param file_uri string Filename that is the scope of the diagnostics
---@param diagnostics lsp.Diagnostic[] List of diagnostics.
---@param build_target string BuildTarget URI
---@param encoding any
---@return table[] of quickfix list items |setqflist-what|
local function diagnostic_lsp_to_toqflist(file_uri, build_target, diagnostics, encoding)
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
    local text = ((diagnostic.code and "[" .. diagnostic.code .. "] ") or "") .. diagnostic.message
    return {
      lnum = start_line,
      col = line_byte_from_position(start_line, start_character, offset_encoding),
      end_lnum = _end_line,
      end_col = line_byte_from_position(_end_line, _end_character, offset_encoding),
      type = diagnostic.severity and errlist_type_map[diagnostic.severity] or 'E',
      text = text,
      source = diagnostic.source,
      filename = vim.uri_to_fname(file_uri),
      vcol = 1,
      namespace = ns,
      user_data = {
        code = diagnostic.code,
        text_document = file_uri,
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

---@param bufnr integer
---@return string[]?
local function get_buf_lines(bufnr)
  if vim.api.nvim_buf_is_loaded(bufnr) then
    return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end

  local filename = vim.api.nvim_buf_get_name(bufnr)
  local f = io.open(filename)
  if not f then
    return
  end

  local content = f:read('*a')
  if not content then
    -- Some LSP servers report diagnostics at a directory level, in which case
    -- io.read() returns nil
    f:close()
    return
  end

  local lines = vim.split(content, '\n')
  f:close()
  return lines
end

---@param severity lsp.DiagnosticSeverity
local function severity_lsp_to_vim(severity)
  if type(severity) == 'string' then
    severity = vim.lsp.protocol.DiagnosticSeverity[severity] --- @type integer
  end
  return severity
end

---@param diagnostics lsp.Diagnostic[]
---@param bufnr integer
---@param client bsp.Client
---@return vim.Diagnostic[]
local function diagnostic_lsp_to_vim(file_uri, build_target, diagnostics, bufnr, client)
  local buf_lines = get_buf_lines(bufnr)
  local offset_encoding = client and client.offset_encoding or 'utf-16'
  --- @param diagnostic lsp.Diagnostic
  --- @return vim.Diagnostic
  return vim.tbl_map(function(diagnostic)
    local start = diagnostic.range.start
    local _end = diagnostic.range['end']
    local text = ((diagnostic.code and "[" .. diagnostic.code .. "] ") or "") .. diagnostic.message
    local line = buf_lines and buf_lines[start.line + 1] or ''
    --- @type vim.Diagnostic
    return {
      lnum = start.line,
      col = vim.str_byteindex(line, offset_encoding, start.character, false),
      end_lnum = _end.line,
      end_col = vim.str_byteindex(line, offset_encoding, _end.character, false),
      severity = severity_lsp_to_vim(diagnostic.severity),
      message = text,
      source = diagnostic.source,
      code = diagnostic.code,
      user_data = {
        bsp = diagnostic,
        code = diagnostic.code,
        text_document = file_uri,
        build_target = build_target
      },
    }
  end, diagnostics)
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

  write_to_run_console(client.name, ctx.client_id, result.message)
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

  write_to_run_console(client.name, ctx.client_id, result.message)
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
    local ns = vim.api.nvim_create_namespace(client.diagnostics_namespace_name)

    if result.reset and result.textDocument.uri == "file:///" and result.buildTarget.uri == "file:///" then
      -- reset all diagnostics for the client
      vim.diagnostic.reset(ns, nil)
      client.diagnostics = {}
      return
    end

    local fname = vim.uri_to_fname(result.textDocument.uri)
    local bufnr = vim.fn.bufadd(fname)
    if not bufnr then
      return
    end

    local vim_diag = diagnostic_lsp_to_vim(result.textDocument.uri, result.buildTarget.uri, result.diagnostics, bufnr, client)

    local diagnostics_key = result.textDocument.uri .. ":" .. result.buildTarget.uri
    if not client.diagnostics[diagnostics_key] or result.reset then
      client.diagnostics[diagnostics_key] = {}
    end

    for _, diag in pairs(vim_diag) do
      table.insert(client.diagnostics[diagnostics_key], diag)
    end

    vim.diagnostic.set(ns, bufnr, client.diagnostics[diagnostics_key])
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

  if result.dataKind == 'test-case-discovered' then
    ---@type bsp.TestCaseDiscoveredData
    local test_case = result.data;

    if not client.test_cases[test_case.buildTarget.uri] then
      client.test_cases[test_case.buildTarget.uri] = {}
    end

    table.insert(client.test_cases[test_case.buildTarget.uri], test_case)

    local notify_message = "found: " .. test_case.buildTarget.uri .. " " .. test_case.fullyQualifiedName
    vim.notify(notify_message, vim.log.levels.INFO)
  end

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
