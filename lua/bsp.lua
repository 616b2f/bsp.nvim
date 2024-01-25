local default_handlers = require('bsp.handlers')
local protocol = require('bsp.protocol')
local ms = protocol.Methods
local api = vim.api
local utils = require('bsp.utils')
local bp_rpc = require('bp.rpc')
local log = require('bp.log')
local uv = vim.uv
local validate = vim.validate
local nvim_err_writeln, nvim_command = api.nvim_err_writeln, api.nvim_command

local BspGroup = vim.api.nvim_create_augroup('bsp', { clear = true })

local bsp = {
  protocol = protocol,

  handlers = default_handlers,

  util = utils,

  -- Allow raw RPC access.
  rpc = bp_rpc,

  -- Export these directly from rpc.
  rpc_response_error = bp_rpc.rpc_response_error,
  client_errors = bp_rpc.client_errors,
}

-- maps request name to the required server_capability in the client.
bsp._request_name_to_capability = {
  [ms.workspace_buildTargets] = { 'workspaceBuildTargetsProvider' },
}

local wait_result_reason = { [-1] = 'timeout', [-2] = 'interrupted', [-3] = 'error' }

--- Gets the path of the logfile used by the BSP client.
---@return string path to log file
function bsp.get_log_path()
  return log.get_filename()
end

--- Concatenates and writes a list of strings to the Vim error buffer.
---
---@param ... string List to write to the buffer
local function err_message(...)
  nvim_err_writeln(table.concat(vim.tbl_flatten({ ... })))
  nvim_command('redraw')
end

local client_index = 0
--- Returns a new, unused client id.
---
---@return integer client_id
local function next_client_id()
  client_index = client_index + 1
  return client_index
end
-- Tracks all clients created via bsp.start_client
local active_clients = {} --- @type table<integer,bsp.Client>
local uninitialized_clients = {} --- @type table<integer,bsp.Client>

--- Gets a client by id, or nil if the id is invalid.
--- The returned client may not yet be fully initialized.
---
---@param client_id integer client id
---
---@return (nil|bsp.Client) client rpc object
function bsp.get_client_by_id(client_id)
  return active_clients[client_id] or uninitialized_clients[client_id]
end

--- Consumes the latest progress messages from all clients and formats them as a string.
--- Empty if there are no clients or if no new messages
---
---@return string
function bsp.status()
  local percentage = nil
  local messages = {}
  for _, client in ipairs(bsp.get_clients()) do
    for progress in client.progress do
      if progress.message then
        local message = progress.message and (progress.originId .. ': ' .. progress.message) or progress.title
        messages[#messages + 1] = message
        if progress.total and progress.progress then
          percentage = math.max(percentage or 0, (progress.progress / progress.total * 100))
        end
      end
      -- else: Doesn't look like work done progress and can be in any format
      -- Just ignore it as there is no sensible way to display it
    end
  end
  local message = table.concat(messages, ', ')
  if percentage then
    return string.format('%3d%%: %s', percentage, message)
  end
  return message
end

--- Augments a validator function with support for optional (nil) values.
---
---@param fn (fun(v): boolean) The original validator function; should return a
---bool.
---@return fun(v): boolean # The augmented function. Also returns true if {v} is
---`nil`.
local function optional_validator(fn)
  return function(v)
    return v == nil or fn(v)
  end
end

---@internal
--- Parses a command invocation into the command itself and its args. If there
--- are no arguments, an empty table is returned as the second argument.
---
---@param input string[]
---@return string command, string[] args #the command and arguments
function bsp._cmd_parts(input)
  validate({
    cmd = {
      input,
      function()
        return vim.tbl_islist(input)
      end,
      'list',
    },
  })

  local cmd = input[1]
  local cmd_args = {}
  -- Don't mutate our input.
  for i, v in ipairs(input) do
    validate({ ['cmd argument'] = { v, 's' } })
    if i > 1 then
      table.insert(cmd_args, v)
    end
  end
  return cmd, cmd_args
end

---@class bsp.get_clients.filter
---@field id integer|nil Match clients by id
---@field name string|nil match clients by name
---@field method string|nil match client by supported method name
---@field workspace_dir URI|nil match client by workspace root dir

--- Get active clients.
---
---@param filter bsp.get_clients.filter|nil (table|nil) A table with
---              key-value pairs used to filter the returned clients.
---              The available keys are:
---               - id (number): Only return clients with the given id
---               - name (string): Only return clients with the given name
---               - method (string): Only return clients supporting the given method
---@return bsp.Client[]: List of |bsp.client| objects
function bsp.get_clients(filter)
  validate({ filter = { filter, 't', true } })

  filter = filter or {}

  local clients = {} --- @type bsp.Client[]

  for client_id in pairs(active_clients) do
    local client = active_clients[client_id]
    if
      client
      and (filter.id == nil or client.id == filter.id)
      and (filter.name == nil or client.name == filter.name)
      and (filter.method == nil or client.supports_method(filter.method))
      and (filter.workspace_dir == nil or client.workspace_dir)
    then
      clients[#clients + 1] = client
    end
  end
  return clients
end

--- Checks whether a given path is a directory.
---
---@param filename (string) path to check
---@return boolean # true if {filename} exists and is a directory, false otherwise
local function is_dir(filename)
  validate({ filename = { filename, 's' } })
  local stat = uv.fs_stat(filename)
  return stat and stat.type == 'directory' or false
end

--- Validates a client configuration as given to |vim.bsp.start_client()|.
---
---@param config (bsp.ClientConfig)
---@return (string|fun(dispatchers:table):table) Command
---@return string[] Arguments
local function validate_client_config(config)
  validate({
    config = { config, 't' },
  })
  validate({
    handlers = { config.handlers, 't', true },
    capabilities = { config.capabilities, 't', true },
    cmd_cwd = { config.cmd_cwd, optional_validator(is_dir), 'directory' },
    cmd_env = { config.cmd_env, 't', true },
    detached = { config.detached, 'b', true },
    name = { config.name, 's', true },
    on_error = { config.on_error, 'f', true },
    on_exit = { config.on_exit, 'f', true },
    on_init = { config.on_init, 'f', true },
    settings = { config.settings, 't', true },
    commands = { config.commands, 't', true },
    before_init = { config.before_init, 'f', true },
    flags = { config.flags, 't', true }
  })
  assert(
    (
      not config.flags
      or not config.flags.debounce_text_changes
      or type(config.flags.debounce_text_changes) == 'number'
    ),
    'flags.debounce_text_changes must be a number with the debounce time in milliseconds'
  )

  local cmd, cmd_args --- @type (string|fun(dispatchers:table):table), string[]
  local config_cmd = config.cmd
  if type(config_cmd) == 'function' then
    cmd = config_cmd
  else
    cmd, cmd_args = bsp._cmd_parts(config_cmd)
  end
  return cmd, cmd_args
end

---@return { [string]: bsp.BspConnectionDetails }
function bsp.findConnectionDetails ()
  local configs = {}

  -- TODO: search all places for connection config
  -- <workspace-dir>/.bsp/
  -- USER: $XDG_DATA_HOME/bsp/
  -- SYSTEM: $XDG_DATA_DIRS/bsp/
  local workspace_bsp_dir = vim.fs.find('.bsp', {
      upward = true,
      type = 'directory'
  })

  if next(workspace_bsp_dir) then
    local files = vim.fs.find(function(name)
      return name:match('.*%.json$')
    end, {
        limit = math.huge,
        type = 'file',
        path = workspace_bsp_dir[1]
    })

    for _, file in pairs(files) do
      if file then
        local json = vim.fn.join(vim.fn.readfile(file), '\n')
        local config = vim.json.decode(json)
        configs[file] = config
      end
    end
  end
  return configs
end

function bsp.setup()
  local connection_details_dict = bsp.findConnectionDetails();
  if not connection_details_dict then return end

  local clients = {}
  for _, connection_detail in pairs(connection_details_dict) do
    local client_id = bsp.start({
      name = connection_detail.name,
      cmd = connection_detail.argv,
      root_dir = uv.cwd(),
    })
    if client_id then
      clients[client_id] = connection_detail
    end
  end

  return clients
end

function bsp.compile_build_target()
  ---@type { client: bsp.Client, target: bsp.BuildTarget }[]
  local client_targets = {}
  local clients = bsp.get_clients()
  for _, client in ipairs(clients) do
    for _, target in pairs(client.build_targets) do
      if target.capabilities.canCompile then
        table.insert(client_targets, {
          client = client,
          target = target
        })
      end
    end
  end

  vim.ui.select(
    client_targets,
    {
      prompt = "select target to compile",
      ---@type fun(item: { client: bsp.Client, target: bsp.BuildTarget }) : string
      format_item = function (item)
        return item.target.displayName
            .. " "
            .. vim.inspect(item.target.tags)
            .. " : " .. item.client.name
      end,
      kind = "bsp.BuildTarget"
    },
    ---@param clientTarget { client: bsp.Client, target: bsp.BuildTarget }
    function (clientTarget)
      if clientTarget then
          ---@type bsp.CompileParams
          local compileParams = {
            targets = { clientTarget.target.id }
          }
          clientTarget.client.request(
            ms.buildTarget_compile,
            compileParams,
            ---@param result bsp.CompileResult
            function (err, result, context, config)
              vim.notify("BSP-Compilation status: " .. bsp.protocol.StatusCode[result.statusCode])
            end,
          0)
      end
    end)
end
function bsp.test_build_target()
  ---@type { client: bsp.Client, target: bsp.BuildTarget }[]
  local client_targets = {}
  local clients = bsp.get_clients()
  for _, client in ipairs(clients) do
    for _, target in pairs(client.build_targets) do
      if target.capabilities.canTest then
        table.insert(client_targets, {
          client = client,
          target = target
        })
      end
    end
  end

  vim.ui.select(client_targets, {
    prompt = "select target to test",
    ---@type fun(item: { client: bsp.Client, target: bsp.BuildTarget }) : string
    format_item = function (item)
      return item.target.displayName
          .. " "
          .. vim.inspect(item.target.tags)
          .. " : " .. item.client.name
    end,
    kind = "bsp.BuildTarget"
  },
  ---@param clientTarget { client: bsp.Client, target: bsp.BuildTarget }
  function (clientTarget)
    if clientTarget then
        ---@type bsp.TestParams
        local testParams = {
          targets = { clientTarget.target.id }
        }
        clientTarget.client.request(
          ms.buildTarget_test,
          testParams,
          ---comment
          ---@param err bp.ResponseError|nil
          ---@param result bsp.TestResult
          ---@param context bsp.HandlerContext
          ---@param config table|nil
          function (err, result, context, config)
            vim.notify("BSP-Test status: " .. bsp.protocol.StatusCode[result.statusCode])
          end,
        0)
    end
  end)
end

function bsp.run_build_target ()
  ---@type { client: bsp.Client, target: bsp.BuildTarget }[]
  local client_targets = {}
  local clients = bsp.get_clients()
  for _, client in ipairs(clients) do
    for _, target in pairs(client.build_targets) do
      if target.capabilities.canRun then
        table.insert(client_targets, {
          client = client,
          target = target
        })
      end
    end
  end

  vim.ui.select(client_targets, {
    prompt = "select target to run",
    ---@type fun(item: { client: bsp.Client, target: bsp.BuildTarget }) : string
    format_item = function (item)
      return item.target.displayName
          .. " "
          .. vim.inspect(item.target.tags)
          .. " : " .. item.client.name
    end,
    kind = "bsp.BuildTarget"
  },
  ---@param clientTarget { client: bsp.Client, target: bsp.BuildTarget }
  function (clientTarget)
    if clientTarget then
        ---@type bsp.RunParams
        local runParams = {
          target = clientTarget.target.id
        }
        clientTarget.client.request(
          ms.buildTarget_run,
          runParams,
          ---comment
          ---@param err bp.ResponseError|nil
          ---@param result bsp.RunResult
          ---@param context bsp.HandlerContext
          ---@param config table|nil
          function (err, result, context, config)
            vim.notify("BSP-Run status: " .. bsp.protocol.StatusCode[result.statusCode])
          end,
        0)
    end
  end)
end

function bsp.cleancache_build_target()
  local clients = bsp.get_clients()
  for _, client in ipairs(clients) do
    local target_ids = {}
    for _, target in pairs(client.build_targets) do
      table.insert(target_ids, target.id)
    end
    if next(target_ids) ~= nil then
      ---@type bsp.CleanCacheParams
      local cleanCacheParams = {
        targets = {target_ids[1]}
      }
      client.request(
        ms.buildTarget_cleanCache,
        cleanCacheParams,
        ---comment
        ---@param err bp.ResponseError|nil
        ---@param result bsp.CleanCacheResult
        ---@param context bsp.HandlerContext
        ---@param config table|nil
        function (err, result, context, config)
          vim.notify("BSP-CleanCache status: cleaned=" .. tostring(result.cleaned) .. " " .. (result.message or ''))
        end,
      0)
    end
  end
end

---@param config bsp.ClientConfig
function bsp.start(config, opts)
  opts = opts or {}
  local reuse_client = opts.reuse_client
    or function(client, conf)
      return client.config.root_dir == conf.root_dir and client.name == conf.name
    end
  if not config.name then
    return nil
  end
  for _, clients in ipairs({ uninitialized_clients, bsp.get_clients() }) do
    for _, client in pairs(clients) do
      if reuse_client(client, config) then
        return client.id
      end
    end
  end
  local client_id = bsp.start_client(config)
  if client_id == nil then
    return nil -- bsp.start_client will have printed an error
  end
  return client_id
end

---@private
--- Sends an async request for all active clients
--- running for specified workspace root directory.
---
---@param workspace_dir (URI) Workspace root directory
---@param method (string) BSP method name
---@param params table|nil Parameters to send to the server
---@param handler? bsp-handler See |bsp-handler|
---       If nil, follows resolution strategy defined in |bsp-handler-configuration|
---
---@return table<integer, integer> client_request_ids Map of client-id:request-id pairs
---for all successful requests.
---@return function _cancel_all_requests Function which can be used to
---cancel all the requests. You could instead
---iterate all clients and call their `cancel_request()` methods.
function bsp.workspace_request(workspace_dir, method, params, handler)
  validate({
    workspace_dir = { workspace_dir, 's', true },
    method = { method, 's' },
    handler = { handler, 'f', true },
  })

  local method_supported = false
  local clients = bsp.get_clients({ workspace_dir = workspace_dir })
  local client_request_ids = {}
  for _, client in ipairs(clients) do
    if client.supports_method(method) then
      method_supported = true

      local request_success, request_id = client.request(method, params, handler, 0)
      -- This could only fail if the client shut down in the time since we looked
      -- it up and we did the request, which should be rare.
      if request_success then
        client_request_ids[client.id] = request_id
      end
    end
  end

  -- if has client but no clients support the given method, notify the user
  if next(clients) and not method_supported then
    local msg = string.format(
      'method %s is not supported by any of the servers registered for the workspace directory',
      method
    )
    vim.notify(msg, vim.log.levels.ERROR)
    nvim_command('redraw')
    return {}, function() end
  end

  local function _cancel_all_requests()
    for client_id, request_id in pairs(client_request_ids) do
      local client = active_clients[client_id]
      client.cancel_request(request_id)
    end
  end

  return client_request_ids, _cancel_all_requests
end

--- Sends an async request for all active clients running for specified workspace root directory and executes the `handler`
--- callback with the combined result.
---
---@param workspace_dir (URI) Workspace root directory.
---@param method (string) BSP method name
---@param params (table|nil) Parameters to send to the server
---@param handler fun(results: table<integer, {error: bp.ResponseError, result: any}>) (function)
--- Handler called after all requests are completed. Server results are passed as
--- a `client_id:result` map.
---@return function cancel Function that cancels all requests.
function bsp.workspace_request_all(workspace_dir, method, params, handler)
  local results = {}
  local result_count = 0
  local expected_result_count = 0

  local clients = bsp.get_clients({ workspace_dir = workspace_dir })
  if clients then
    expected_result_count = #clients
  end

  local function _sync_handler(err, result, ctx)
    results[ctx.client_id] = { error = err, result = result }
    result_count = result_count + 1

    if result_count >= expected_result_count then
      handler(results)
    end
  end

  local _, cancel = bsp.workspace_request(workspace_dir, method, params, _sync_handler)

  return cancel
end

--- Sends a request to all server and waits for the response of all of them.
---
--- Calls |bsp.workspace_request_all()| but blocks Nvim while awaiting the result.
--- Parameters are the same as |bsp.workspace_request_all()| but the result is
--- different. Waits a maximum of {timeout_ms} (default 1000) ms.
---
---@param workspace_dir (URI) Workspace root directory
---@param method (string) BSP method name
---@param params (table|nil) Parameters to send to the server
---@param timeout_ms (integer|nil) Maximum time in milliseconds to wait for a
---                               result. Defaults to 1000
---
---@return table<integer, {err: bp.ResponseError, result: any}>|nil (table) result Map of client_id:request_result.
---@return string|nil err On timeout, cancel, or error, `err` is a string describing the failure reason, and `result` is nil.
function bsp.workspace_request_sync(workspace_dir, method, params, timeout_ms)
  local request_results

  local cancel = bsp.workspace_request_all(workspace_dir, method, params, function(it)
    request_results = it
  end)

  local wait_result, reason = vim.wait(timeout_ms or 1000, function()
    return request_results ~= nil
  end, 10)

  if not wait_result then
    cancel()
    return nil, wait_result_reason[reason]
  end

  return request_results
end

--- @class bsp.ClientConfig
--- @field cmd (string[]|fun(dispatchers: table):table)
--- @field cmd_cwd string
--- @field cmd_env (table)
--- @field detached boolean
--- @field workspace_folders (table)
--- @field capabilities bsp.BuildClientCapabilities
--- @field handlers table<string,function>
--- @field settings table
--- @field commands table
--- @field init_options table
--- @field name string
--- @field offset_encoding string
--- @field on_error fun(code: integer)
--- @field before_init function
--- @field on_init function
--- @field on_exit fun(code: integer, signal: integer, client_id: integer)
--- @field on_attach fun(client: bsp.Client)
--- @field trace 'off'|'messages'|'verbose'|nil
--- @field flags table
--- @field root_dir URI Workspace root directory
function bsp.start_client(config)
  local cmd, cmd_args, offset_encoding = validate_client_config(config)

  config.flags = config.flags or {}
  config.settings = config.settings or {}

  local client_id = next_client_id()

  local handlers = config.handlers or {}
  local name = config.name or tostring(client_id)
  local log_context = string.format('bsp:%s', name)
  local logger = log.new_logger(log_context)

  ---@type bp.rpc.Dispatchers
  local dispatch = {}

  --- Returns the handler associated with an BSP method.
  --- Returns the default handler if the user hasn't set a custom one.
  ---
  ---@param method string BSP method name
  ---@return bsp-handler|nil The handler for the given method, if defined, or the default from |vim.bsp.handlers|
  local function resolve_handler(method)
    return handlers[method] or default_handlers[method]
  end

  ---@private
  ---@param method string BSP method name
  ---@param params table The parameters for that method.
  function dispatch.notification(method, params)
    if logger.trace() then
      logger.trace('notification', method, params)
    end
    local handler = resolve_handler(method)
    if handler then
      -- Method name is provided here for convenience.
      handler(nil, params, { method = method, client_id = client_id })
    end
  end

  ---@private
  ---@param method string BSP method name
  ---@param params table The parameters for that method
  function dispatch.server_request(method, params)
    if logger.trace() then
      logger.trace('server_request', method, params)
    end
    local handler = resolve_handler(method)
    if handler then
      if logger.trace() then
        logger.trace('server_request: found handler for', method)
      end
      return handler(nil, params, { method = method, client_id = client_id })
    end
    if logger.warn() then
      logger.warn('server_request: no handler found for', method)
    end
    return nil, bsp.rpc_response_error(protocol.ErrorCodes.MethodNotFound)
  end

  ---Logs the given error to the BSP log and to the error buffer.
  ---@param code integer Error code
  ---@param err any Error arguments
  local function write_error(code, err)
    if logger.error() then
      logger.error('on_error', { code = bsp.client_errors[code], err = err })
    end
    err_message(log_context, ': Error ', bsp.client_errors[code], ': ', vim.inspect(err))
  end

  ---@private
  ---@param code (integer) Error code
  ---@param err (...) Other arguments may be passed depending on the error kind
  ---@see vim.bsp.rpc.client_errors for possible errors. Use
  ---`vim.bsp.rpc.client_errors[code]` to get a human-friendly name.
  function dispatch.on_error(code, err)
    write_error(code, err)
    if config.on_error then
      local status, usererr = pcall(config.on_error, code, err)
      if not status then
        local _ = logger.error() and logger.error('user on_error failed', { err = usererr })
        err_message(log_context, ' user on_error failed: ', tostring(usererr))
      end
    end
  end

  ---@private
  ---@param code (integer) exit code of the process
  ---@param signal (integer) the signal used to terminate (if any)
  function dispatch.on_exit(code, signal)
    if config.on_exit then
      pcall(config.on_exit, code, signal, client_id)
    end

    -- Schedule the deletion of the client object so that it exists in the execution of BspDetach
    -- autocommands
    vim.schedule(function()
      active_clients[client_id] = nil
      uninitialized_clients[client_id] = nil

      if code ~= 0 or (signal ~= 0 and signal ~= 15) then
        local msg = string.format(
          'Client %s quit with exit code %s and signal %s. Check log for errors: %s',
          name,
          code,
          signal,
          bsp.get_log_path()
        )
        vim.notify(msg, vim.log.levels.WARN)
      end
    end)
  end

  -- Start the RPC client.
  local rpc
  if type(cmd) == 'function' then
    rpc = cmd(dispatch)
  else
    rpc = bp_rpc.start(
      cmd,
      cmd_args,
      dispatch,
      {
        cwd = config.cmd_cwd,
        env = config.cmd_env,
        detached = config.detached,
      },
      logger)
  end

  -- Return nil if client fails to start
  if not rpc then
    return
  end

  ---@class bsp.Client
  local client = {
    id = client_id,
    name = name,
    rpc = rpc,
    offset_encoding = offset_encoding,
    config = config,

    handlers = handlers,
    commands = config.commands or {},

    --- @type table<integer,{ type: string, bufnr: integer, method: string}>
    requests = {},

    --- Contains progress report messages.
    --- For "task progress", value will be one of:
    --- - bsp.TaskStartParams,
    --- - bsp.TaskProgressParams,
    --- - bsp.TaskFinishParams,
    progress = vim.ringbuf(50),

    ---@type bsp.BuildServerCapabilities
    server_capabilities = {},

    ---@type table<URI,bsp.BuildTarget> table of build targets by target URI
    build_targets = {},

    ---@type table<bsp.ResourcesItem>
    resources = {},

    ---@type table<bsp.DependencySourcesItem>
    dependency_sources = {},

    ---@type table<bsp.SourcesItem>
    sources = {},

    ---@type table<bsp.OutputPathsItem>
    output_paths = {},

    ---@type URI
    workspace_dir = config.root_dir
  }

  ---@type table<string|integer, string> title of unfinished progress sequences by token
  client.progress.pending = {}

  --- @type bsp.BuildClientCapabilities
  client.config.capabilities = config.capabilities or protocol.make_client_capabilities()

  -- Store the uninitialized_clients for cleanup in case we exit before initialize finishes.
  uninitialized_clients[client_id] = client

  local function initialize()
    --TODO use traces enum from BP
    local valid_traces = {
      off = 'off',
      messages = 'messages',
      verbose = 'verbose',
    }

    local workspace_folders --- @type table[]?
    local root_uri --- @type string?
    if config.workspace_folders or config.root_dir then
      if config.root_dir and not config.workspace_folders then
        workspace_folders = {
          {
            uri = vim.uri_from_fname(config.root_dir),
            name = string.format('%s', config.root_dir),
          },
        }
      else
        workspace_folders = config.workspace_folders
      end
      root_uri = workspace_folders[1].uri
    else
      workspace_folders = nil
      root_uri = nil
    end

    ---@type bsp.InitializeBuildParams
    local initialize_params = {
      -- Information about the client
      displayName = 'Neovim',
      version = tostring(vim.version()),
      bspVersion = '2.1.0',
      -- The rootUri of the workspace. Is null if no folder is open.
      rootUri = root_uri or vim.NIL,
      -- The workspace folders configured in the client when the server starts.
      -- This property is only available if the client supports workspace folders.
      -- It can be `null` if the client supports workspace folders but none are
      -- configured.
      workspaceFolders = workspace_folders or vim.NIL,
      -- User provided initialization options.
      initializationOptions = config.init_options,
      -- The capabilities provided by the client (editor or tool)
      capabilities = config.capabilities,
      -- The initial trace setting. If omitted trace is disabled ("off").
      -- trace = "off" | "messages" | "verbose";
      trace = valid_traces[config.trace] or 'off',
    }

    if config.before_init then
      local status, err = pcall(config.before_init, initialize_params, config)
      if not status then
        write_error(bsp.client_errors.BEFORE_INIT_CALLBACK_ERROR, err)
      end
    end

    --- @param method string
    client.supports_method = function(method)
      local required_capability = bsp._request_name_to_capability[method]
      -- if we don't know about the method, assume that the client supports it.
      if required_capability then
        return true
      end
    end

    local _ = logger.trace() and logger.trace('InitializeBuildParams', initialize_params)
    --- Initialize request, has always to be send first.
    ---@param init_err bp.ResponseError|nil
    ---@param result bsp.InitializeBuildResult
    rpc.request(ms.build_initialize, initialize_params, function(init_err, result)
      assert(not init_err, tostring(init_err))
      assert(result, 'server sent empty result')
      rpc.notify(ms.build_initialized, vim.empty_dict())
      client.initialized = true
      uninitialized_clients[client_id] = nil
      client.workspace_folders = workspace_folders

      -- These are the cleaned up capabilities we use for dynamically deciding
      -- when to send certain events to clients.
      client.server_capabilities =
        assert(result.capabilities, "initialize result doesn't contain capabilities")

      if next(config.settings) then
        client.notify(ms.workspace_didChangeConfiguration, { settings = config.settings })
      end

      if config.on_init then
        local status, err = pcall(config.on_init, client, result)
        if not status then
          write_error(bsp.client_errors.ON_INIT_CALLBACK_ERROR, err)
        end
      end

      -- load project related data and save it in the client properties
      client.load_project_data()

      local _ = logger.info()
        and logger.info(
          'server_capabilities',
          { server_capabilities = client.server_capabilities }
        )

      -- Only assign after initialized.
      active_clients[client_id] = client
      client._on_attach()
    end)
  end

  ---@nodoc
  --- Sends a request to the server.
  ---
  --- This is a thin wrapper around {client.rpc.request} with some additional
  --- checks for capabilities and handler availability.
  ---
  ---@param method string BSP method name.
  ---@param params? table BSP request params.
  ---@param handler bsp-handler|nil Response |bsp-handler| for this method.
  ---@param bufnr integer Buffer handle (0 for current).
  ---@return boolean status, integer|nil request_id {status} is a bool indicating
  ---whether the request was successful. If it is `false`, then it will
  ---always be `false` (the client has shutdown). If it was
  ---successful, then it will return {request_id} as the
  ---second result. You can use this with `client.cancel_request(request_id)`
  ---to cancel the-request.
  ---@see |bsp.workspace_request_all()|
  function client.request(method, params, handler, bufnr)
    if not handler then
      handler = assert(
        resolve_handler(method),
        string.format('not found: %q request handler for client %q.', method, client.name)
      )
    end
    if logger.debug() then
      logger.debug('client.request', client_id, method, params, handler, bufnr)
    end
    local success, request_id = rpc.request(method, params, function(err, result)
      local context = {
        method = method,
        client_id = client_id,
        bufnr = bufnr,
        params = params,
      }
      handler(err, result, context)
    end, function(request_id)
      local request = client.requests[request_id]
      request.type = 'complete'
      api.nvim_exec_autocmds('User', {
        pattern = 'BspRequest',
        group = BspGroup,
        modeline = false,
        data = { client_id = client_id, request_id = request_id, request = request },
      })
      client.requests[request_id] = nil
    end)

    if success and request_id then
      local request = { type = 'pending', bufnr = bufnr, method = method }
      client.requests[request_id] = request
      api.nvim_exec_autocmds('User', {
        pattern = 'BspRequest',
        group = BspGroup,
        modeline = false,
        data = { client_id = client_id, request_id = request_id, request = request },
      })
    end

    return success, request_id
  end

  ---@private
  --- Sends a request to the server and synchronously waits for the response.
  ---
  --- This is a wrapper around {client.request}
  ---
  ---@param method string BSP method name.
  ---@param params? table BSP request params.
  ---@param timeout_ms? integer Maximum time in milliseconds to wait for
  ---                               a result. Defaults to 1000
  ---@param bufnr integer Buffer handle (0 for current).
  ---@return {err: bp.ResponseError|nil, result:any}|nil, string|nil err # a dictionary, where
  --- `err` and `result` come from the |bsp-handler|.
  --- On timeout, cancel or error, returns `(nil, err)` where `err` is a
  --- string describing the failure reason. If the request was unsuccessful
  --- returns `nil`.
  ---@see |bsp.workspace_request_sync()|
  function client.request_sync(method, params, timeout_ms, bufnr)
    local request_result = nil
    local function _sync_handler(err, result)
      request_result = { err = err, result = result }
    end

    local success, request_id = client.request(method, params, _sync_handler, bufnr)
    if not success then
      return nil
    end

    local wait_result, reason = vim.wait(timeout_ms or 1000, function()
      return request_result ~= nil
    end, 10)

    if not wait_result then
      if request_id then
        client.cancel_request(request_id)
      end
      return nil, wait_result_reason[reason]
    end
    return request_result
  end

  ---@nodoc
  --- Sends a notification to an BSP server.
  ---
  ---@param method string BSP method name.
  ---@param params table|nil BSP request params.
  ---@return boolean status true if the notification was successful.
  ---If it is false, then it will always be false
  ---(the client has shutdown).
  function client.notify(method, params)
    local client_active = rpc.notify(method, params)

    if client_active then
      vim.schedule(function()
        api.nvim_exec_autocmds('User', {
          pattern = 'BspNotify',
          group = BspGroup,
          modeline = false,
          data = {
            client_id = client.id,
            method = method,
            params = params,
          },
        })
      end)
    end

    return client_active
  end

  ---@nodoc
  --- Cancels a request with a given request id.
  ---
  ---@param id (integer) id of request to cancel
  ---@return boolean status true if notification was successful. false otherwise
  ---@see |bsp.client.notify()|
  function client.cancel_request(id)
    validate({ id = { id, 'n' } })
    local request = client.requests[id]
    if request and request.type == 'pending' then
      request.type = 'cancel'
      api.nvim_exec_autocmds('User', {
        pattern = 'BspRequest',
        group = BspGroup,
        modeline = false,
        data = { client_id = client_id, request_id = id, request = request },
      })
    end
    return rpc.notify(ms.dollar_cancelRequest, { id = id })
  end

  -- Track this so that we can escalate automatically if we've already tried a
  -- graceful shutdown
  local graceful_shutdown_failed = false

  ---@nodoc
  --- Stops a client, optionally with force.
  ---
  ---By default, it will just ask the - server to shutdown without force. If
  --- you request to stop a client which has previously been requested to
  --- shutdown, it will automatically escalate and force shutdown.
  ---
  ---@param force boolean|nil
  function client.stop(force)
    if rpc.is_closing() then
      return
    end
    if force or not client.initialized or graceful_shutdown_failed then
      rpc.terminate()
      return
    end
    -- Sending a signal after a process has exited is acceptable.
    rpc.request(ms.build_shutdown, nil, function(err, _)
      if err == nil then
        rpc.notify(ms.build_exit)
      else
        -- If there was an error in the shutdown request, then term to be safe.
        rpc.terminate()
        graceful_shutdown_failed = true
      end
    end)
  end

  ---@private
  --- Checks whether a client is stopped.
  ---
  ---@return boolean # true if client is stopped or in the process of being
  ---stopped; false otherwise
  function client.is_stopped()
    return rpc.is_closing()
  end

  ---@private
  --- Load project related data
  ---
  function client.load_project_data()
    --TODO: handle error case properly
    local request_success, request_id = client.request(ms.workspace_buildTargets, nil,
      ---@param result bsp.WorkspaceBuildTargetsResult
      function (err, result, context, config)
        if result then
          local build_target_identifier = {}
          for _, target in ipairs(result.targets) do
            client.build_targets[target.id.uri] = target
            table.insert(build_target_identifier, target.id)
          end

          ---@type bsp.SourcesParams
          local sources_params = {
              targets = build_target_identifier
          }
          local request_success, request_id = client.request(ms.buildTarget_sources, sources_params,
            ---@param result bsp.SourcesResult
            function (err, result, context, config)
              if result then
                client.sources = result.items
              end
            end,
            0)

          if client.server_capabilities.resourcesProvider then
            ---@type bsp.ResourcesParams
            local resources_params = {
                targets = build_target_identifier
            }
            local request_success, request_id = client.request(ms.buildTarget_resources, resources_params,
              ---@param result bsp.ResourcesResult
              function (err, result, context, config)
                if result then
                  client.resources = result.items
                end
              end,
              0)
          end

          if client.server_capabilities.dependencySourcesProvider then
            ---@type bsp.DependencySourcesParams
            local dependency_sources_params = {
                targets = build_target_identifier
            }
            if client.server_capabilities.dependencySourcesProvider then
              local request_success, request_id = client.request(ms.buildTarget_dependencySources, dependency_sources_params,
                ---@param result bsp.DependencySourcesResult
                function (err, result, context, config)
                  if result then
                    client.dependency_sources = result.items
                  end
                end,
                0)
            end
          end

          if client.server_capabilities.outputPathsProvider then
            ---@type bsp.OutputPathsParams
            local output_paths_params = {
                targets = build_target_identifier
            }
            local request_success, request_id = client.request(ms.buildTarget_outputPaths, output_paths_params,
              ---@param result bsp.OutputPathsResult
              function (err, result, context, config)
                if result then
                  client.output_paths = result.items
                end
              end,
              0)
          end
        end
      end,
      0)
  end

  ---@private
  --- Execute a bsp command, either via client command function (if available)
  --- or via workspace/executeCommand (if supported by the server)
  ---
  ---@param command bsp.Command
  ---@param context? {bufnr: integer}
  ---@param handler? bsp-handler only called if a server command
  function client._exec_cmd(command, context, handler)
    context = vim.deepcopy(context or {})
    context.bufnr = context.bufnr or api.nvim_get_current_buf()
    context.client_id = client.id
    local cmdname = command.command
    local fn = client.commands[cmdname] or bsp.commands[cmdname]
    if fn then
      fn(command, context)
      return
    end

    local command_provider = client.server_capabilities.executeCommandProvider
    local commands = type(command_provider) == 'table' and command_provider.commands or {}
    if not vim.list_contains(commands, cmdname) then
      vim.notify_once(
        string.format(
          'Build server `%s` does not support command `%s`. This command may require a client extension.',
          client.name,
          cmdname
        ),
        vim.log.levels.WARN
      )
      return
    end
    -- Not using command directly to exclude extra properties,
    -- see https://github.com/python-lsp/python-lsp-server/issues/146
    local params = {
      command = command.command,
      arguments = command.arguments,
    }
    client.request(ms.workspace_executeCommand, params, handler, context.bufnr)
  end

  ---@private
  --- Runs the on_attach function from the client's config if it was defined.
  function client._on_attach()
    api.nvim_exec_autocmds('User', {
      pattern = 'BspAttach',
      group = BspGroup,
      modeline = false,
      data = { client_id = client.id },
    })

    if config.on_attach then
      local status, err = pcall(config.on_attach, client)
      if not status then
        write_error(bsp.client_errors.ON_ATTACH_ERROR, err)
      end
    end
  end

  initialize()

  return client_id
end

return bsp
