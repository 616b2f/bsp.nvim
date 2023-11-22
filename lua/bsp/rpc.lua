local uv = vim.uv
local log = require('bsp.log')
local protocol = require('bsp.protocol')
local validate, schedule, schedule_wrap = vim.validate, vim.schedule, vim.schedule_wrap

local is_win = uv.os_uname().version:find('Windows')

--- Checks whether a given path exists and is a directory.
---@param filename (string) path to check
---@return boolean
local function is_dir(filename)
  local stat = uv.fs_stat(filename)
  return stat and stat.type == 'directory' or false
end

--- Embeds the given string into a table and correctly computes `Content-Length`.
---
---@param encoded_message (string)
---@return string #string containing encoded message and `Content-Length` attribute
local function format_message_with_content_length(encoded_message)
  return table.concat({
    'Content-Length: ',
    tostring(#encoded_message),
    '\r\n\r\n',
    encoded_message,
  })
end

---@alias bsp.rpc.Headers table<string, string>|{content_length: integer}

--- Parses an BSP Message's header
---
---@param header string The header to parse.
---@return bsp.rpc.Headers #parsed headers
local function parse_headers(header)
  assert(type(header) == 'string', 'header must be a string')
  ---@type bsp.rpc.Headers
  local headers = {}
  for line in vim.gsplit(header, '\r\n', { plain = true }) do
    if line == '' then
      break
    end
    local key, value = line:match('^%s*(%S+)%s*:%s*(.+)%s*$')
    if key and value then
      ---@cast value string
      ---@cast key string
      key = key:lower():gsub('%-', '_')
      headers[key] = value
    else
      local _ = log.error() and log.error('invalid header line %q', line)
      error(string.format('invalid header line %q', line))
    end
  end
  headers.content_length = tonumber(headers.content_length)
    or error(string.format('Content-Length not found in headers. %q', header))
  return headers
end

-- This is the start of any possible header patterns. The gsub converts it to a
-- case insensitive pattern.
local header_start_pattern = ('content'):gsub('%w', function(c)
  return '[' .. c .. c:upper() .. ']'
end)

--- The actual workhorse.
local function request_parser_loop()
  local buffer = '' -- only for header part
  while true do
    -- A message can only be complete if it has a double CRLF and also the full
    -- payload, so first let's check for the CRLFs
    local start, finish = buffer:find('\r\n\r\n', 1, true)
    -- Start parsing the headers
    if start then
      -- This is a workaround for servers sending initial garbage before
      -- sending headers, such as if a bash script sends stdout. It assumes
      -- that we know all of the headers ahead of time. At this moment, the
      -- only valid headers start with "Content-*", so that's the thing we will
      -- be searching for.
      -- TODO(ashkan) I'd like to remove this, but it seems permanent :(
      local buffer_start = buffer:find(header_start_pattern)
      if not buffer_start then
        error(
          string.format(
            "Headers were expected, a different response was received. The server response was '%s'.",
            buffer
          )
        )
      end
      local headers = parse_headers(buffer:sub(buffer_start, start - 1))
      local content_length = headers.content_length
      -- Use table instead of just string to buffer the message. It prevents
      -- a ton of strings allocating.
      -- ref. http://www.lua.org/pil/11.6.html
      ---@type string[]
      local body_chunks = { buffer:sub(finish + 1) }
      local body_length = #body_chunks[1]
      -- Keep waiting for data until we have enough.
      while body_length < content_length do
        ---@type string
        local chunk = coroutine.yield()
          or error('Expected more data for the body. The server may have died.') -- TODO hmm.
        table.insert(body_chunks, chunk)
        body_length = body_length + #chunk
      end
      local last_chunk = body_chunks[#body_chunks]

      body_chunks[#body_chunks] = last_chunk:sub(1, content_length - body_length - 1)
      local rest = ''
      if body_length > content_length then
        rest = last_chunk:sub(content_length - body_length)
      end
      local body = table.concat(body_chunks)
      -- Yield our data.
      buffer = rest
        .. (
          coroutine.yield(headers, body)
          or error('Expected more data for the body. The server may have died.')
        ) -- TODO hmm.
    else
      -- Get more data since we don't have enough.
      buffer = buffer
        .. (
          coroutine.yield() or error('Expected more data for the header. The server may have died.')
        ) -- TODO hmm.
    end
  end
end

local M = {}

--- Mapping of error codes used by the client
--- @nodoc
M.client_errors = {
  INVALID_SERVER_MESSAGE = 1,
  INVALID_SERVER_JSON = 2,
  NO_RESULT_CALLBACK_FOUND = 3,
  READ_ERROR = 4,
  NOTIFICATION_HANDLER_ERROR = 5,
  SERVER_REQUEST_HANDLER_ERROR = 6,
  SERVER_RESULT_CALLBACK_ERROR = 7,
}

M.client_errors = vim.tbl_add_reverse_lookup(M.client_errors)

--- Constructs an error message from an BSP error object.
---
---@param err (table) The error object
---@return (string) #The formatted error message
function M.format_rpc_error(err)
  validate({
    err = { err, 't' },
  })

  -- There is ErrorCodes in the BSP specification,
  -- but in ResponseError.code it is not used and the actual type is number.
  ---@type string
  local code
  if protocol.ErrorCodes[err.code] then
    code = string.format('code_name = %s,', protocol.ErrorCodes[err.code])
  else
    code = string.format('code_name = unknown, code = %s,', err.code)
  end

  local message_parts = { 'RPC[Error]', code }
  if err.message then
    table.insert(message_parts, 'message =')
    table.insert(message_parts, string.format('%q', err.message))
  end
  if err.data then
    table.insert(message_parts, 'data =')
    table.insert(message_parts, vim.inspect(err.data))
  end
  return table.concat(message_parts, ' ')
end

---@class bsp.rpc.RpcError
---@field code integer RPC error code defined in |bsp.protocol.ErrorCodes|
---@field message string? arbitrary message to send to server
---@field data any? arbitrary data to send to server

--- Creates an RPC response object/table.
---
---@param code integer RPC error code defined in |bsp.protocol.ErrorCodes|
---@param message string? arbitrary message to send to server
---@param data any? arbitrary data to send to server
---@return bsp.rpc.RpcError
function M.rpc_response_error(code, message, data)
  -- TODO should this error or just pick a sane error (like InternalError)?
  local code_name = assert(protocol.ErrorCodes[code], 'Invalid RPC error code')
  return setmetatable({
    code = code,
    message = message or code_name,
    data = data,
  }, {
    __tostring = M.format_rpc_error,
  })
end

local default_dispatchers = {}

---@private
--- Default dispatcher for notifications sent to an BSP server.
---
---@param method (string) The invoked BSP method
---@param params (table) Parameters for the invoked BSP method
function default_dispatchers.notification(method, params)
  local _ = log.debug() and log.debug('notification', method, params)
end

---@private
--- Default dispatcher for requests sent to an BSP server.
---
---@param method (string) The invoked BSP method
---@param params (table) Parameters for the invoked BSP method
---@return nil
---@return bsp.rpc.RpcError #|bsp.protocol.ErrorCodes.MethodNotFound|
function default_dispatchers.server_request(method, params)
  local _ = log.debug() and log.debug('server_request', method, params)
  return nil, M.rpc_response_error(protocol.ErrorCodes.MethodNotFound)
end

---@private
--- Default dispatcher for when a client exits.
---
---@param code (integer) Exit code
---@param signal (integer) Number describing the signal used to terminate (if
---any)
function default_dispatchers.on_exit(code, signal)
  local _ = log.info() and log.info('client_exit', { code = code, signal = signal })
end

---@private
--- Default dispatcher for client errors.
---
---@param code (integer) Error code
---@param err (any) Details about the error
---any)
function default_dispatchers.on_error(code, err)
  local _ = log.error() and log.error('client_error:', M.client_errors[code], err)
end

---@cast default_dispatchers bsp.rpc.Dispatchers

---@private
function M.create_read_loop(handle_body, on_no_chunk, on_error)
  local parse_chunk = coroutine.wrap(request_parser_loop) --[[@as fun(chunk: string?): bsp.rpc.Headers?, string?]]
  parse_chunk()
  return function(err, chunk)
    if err then
      on_error(err)
      return
    end

    if not chunk then
      if on_no_chunk then
        on_no_chunk()
      end
      return
    end

    while true do
      local headers, body = parse_chunk(chunk)
      if headers then
        handle_body(body)
        chunk = ''
      else
        break
      end
    end
  end
end

---@class bsp.rpc.RpcClient
---@field message_index integer
---@field message_callbacks table<integer, function> dict of message_id to callback
---@field notify_reply_callbacks table<integer, function> dict of message_id to callback
---@field transport bsp.rpc.Transport
---@field dispatchers bsp.rpc.Dispatchers

---@class bsp.rpc.RpcClient
local Client = {}

---@private
function Client:encode_and_send(payload)
  local _ = log.debug() and log.debug('rpc.send', payload)
  if self.transport.is_closing() then
    return false
  end
  local encoded = assert(
    vim.json.encode(payload),
    string.format("Couldn't encode payload '%s'", vim.inspect(payload))
  )
  self.transport.write(format_message_with_content_length(encoded))
  return true
end

---@private
--- Sends a notification to the BSP server.
---@param method (string) The invoked BSP method
---@param params (any) Parameters for the invoked BSP method
---@return boolean `true` if notification could be sent, `false` if not
function Client:notify(method, params)
  return self:encode_and_send({
    jsonrpc = '2.0',
    method = method,
    params = params,
  })
end

---@private
--- sends an error object to the remote BSP process.
function Client:send_response(request_id, err, result)
  return self:encode_and_send({
    id = request_id,
    jsonrpc = '2.0',
    error = err,
    result = result,
  })
end

---@private
--- Sends a request to the BSP server and runs {callback} upon response.
---
---@param method (string) The invoked BSP method
---@param params (table?) Parameters for the invoked BSP method
---@param callback fun(err: bsp.ResponseError?, result: any) Callback to invoke
---@param notify_reply_callback (function?) Callback to invoke as soon as a request is no longer pending
---@return boolean success, integer? request_id true, request_id if request could be sent, `false` if not
function Client:request(method, params, callback, notify_reply_callback)
  validate({
    callback = { callback, 'f' },
    notify_reply_callback = { notify_reply_callback, 'f', true },
  })
  self.message_index = self.message_index + 1
  local message_id = self.message_index
  local result = self:encode_and_send({
    id = message_id,
    jsonrpc = '2.0',
    method = method,
    params = params,
  })
  local message_callbacks = self.message_callbacks
  local notify_reply_callbacks = self.notify_reply_callbacks
  if result then
    if message_callbacks then
      message_callbacks[message_id] = schedule_wrap(callback)
    else
      return false
    end
    if notify_reply_callback and notify_reply_callbacks then
      notify_reply_callbacks[message_id] = schedule_wrap(notify_reply_callback)
    end
    return result, message_id
  else
    return false
  end
end

---@private
---@param errkind integer
---@param ... any
function Client:on_error(errkind, ...)
  assert(M.client_errors[errkind])
  -- TODO what to do if this fails?
  pcall(self.dispatchers.on_error, errkind, ...)
end

---@private
---@param errkind integer
---@param status boolean
---@param head any
---@param ... any
---@return boolean status
---@return any head
---@return any? ...
function Client:pcall_handler(errkind, status, head, ...)
  if not status then
    self:on_error(errkind, head, ...)
    return status, head
  end
  return status, head, ...
end

---@private
---@param errkind integer
---@param fn function
---@param ... any
---@return boolean status
---@return any head
---@return any? ...
function Client:try_call(errkind, fn, ...)
  return self:pcall_handler(errkind, pcall(fn, ...))
end

-- TODO periodically check message_callbacks for old requests past a certain
-- time and log them. This would require storing the timestamp. I could call
-- them with an error then, perhaps.

---@private
function Client:handle_body(body)
  local ok, decoded = pcall(vim.json.decode, body, { luanil = { object = true } })
  if not ok then
    self:on_error(M.client_errors.INVALID_SERVER_JSON, decoded)
    return
  end
  local _ = log.debug() and log.debug('rpc.receive', decoded)

  if type(decoded.method) == 'string' and decoded.id then
    ---@type bsp.rpc.RpcError?
    local err
    -- Schedule here so that the users functions don't trigger an error and
    -- we can still use the result.
    schedule(function()
      coroutine.wrap(function()
        local status, result
        status, result, err = self:try_call(
          M.client_errors.SERVER_REQUEST_HANDLER_ERROR,
          self.dispatchers.server_request,
          decoded.method,
          decoded.params
        )
        local _ = log.debug()
          and log.debug(
            'server_request: callback result',
            { status = status, result = result, err = err }
          )
        if status then
          if result == nil and err == nil then
            error(
              string.format(
                'method %q: either a result or an error must be sent to the server in response',
                decoded.method
              )
            )
          end
          if err then
            ---@cast err bsp.rpc.RpcError
            assert(
              type(err) == 'table',
              'err must be a table. Use rpc_response_error to help format errors.'
            )
            local code_name = assert(
              protocol.ErrorCodes[err.code],
              'Errors must use protocol.ErrorCodes. Use rpc_response_error to help format errors.'
            )
            err.message = err.message or code_name
          end
        else
          -- On an exception, result will contain the error message.
          err = M.rpc_response_error(protocol.ErrorCodes.InternalError, result)
          result = nil
        end
        self:send_response(decoded.id, err, result)
      end)()
    end)
    -- This works because we are expecting vim.NIL here
  elseif decoded.id and (decoded.result ~= vim.NIL or decoded.error ~= vim.NIL) then
    -- We sent a number, so we expect a number.
    local result_id = assert(tonumber(decoded.id), 'response id must be a number')

    -- Notify the user that a response was received for the request
    local notify_reply_callbacks = self.notify_reply_callbacks
    local notify_reply_callback = notify_reply_callbacks and notify_reply_callbacks[result_id]
    if notify_reply_callback then
      validate({
        notify_reply_callback = { notify_reply_callback, 'f' },
      })
      notify_reply_callback(result_id)
      notify_reply_callbacks[result_id] = nil
    end

    local message_callbacks = self.message_callbacks

    -- Do not surface RequestCancelled to users, it is RPC-internal.
    if decoded.error then
      local mute_error = false
      if decoded.error.code == protocol.ErrorCodes.RequestCancelled then
        local _ = log.debug() and log.debug('Received cancellation ack', decoded)
        mute_error = true
      end

      if mute_error then
        -- Clear any callback since this is cancelled now.
        -- This is safe to do assuming that these conditions hold:
        -- - The server will not send a result callback after this cancellation.
        -- - If the server sent this cancellation ACK after sending the result, the user of this RPC
        -- client will ignore the result themselves.
        if result_id and message_callbacks then
          message_callbacks[result_id] = nil
        end
        return
      end
    end

    local callback = message_callbacks and message_callbacks[result_id]
    if callback then
      message_callbacks[result_id] = nil
      validate({
        callback = { callback, 'f' },
      })
      if decoded.error then
        decoded.error = setmetatable(decoded.error, {
          __tostring = M.format_rpc_error,
        })
      end
      self:try_call(
        M.client_errors.SERVER_RESULT_CALLBACK_ERROR,
        callback,
        decoded.error,
        decoded.result
      )
    else
      self:on_error(M.client_errors.NO_RESULT_CALLBACK_FOUND, decoded)
      local _ = log.error() and log.error('No callback found for server response id ' .. result_id)
    end
  elseif type(decoded.method) == 'string' then
    -- Notification
    self:try_call(
      M.client_errors.NOTIFICATION_HANDLER_ERROR,
      self.dispatchers.notification,
      decoded.method,
      decoded.params
    )
  else
    -- Invalid server message
    self:on_error(M.client_errors.INVALID_SERVER_MESSAGE, decoded)
  end
end

---@class bsp.rpc.Transport
---@field write fun(msg: string): nil
---@field is_closing fun(): boolean|nil
---@field terminate fun(): nil

---@param dispatchers bsp.rpc.Dispatchers
---@param transport bsp.rpc.Transport
---@return bsp.rpc.RpcClient
local function new_client(dispatchers, transport)
  local state = {
    message_index = 0,
    message_callbacks = {},
    notify_reply_callbacks = {},
    transport = transport,
    dispatchers = dispatchers,
  }
  return setmetatable(state, { __index = Client })
end

---@param client bsp.rpc.RpcClient
---@return bsp.rpc.PublicRpcClient
local function public_client(client)
  local result = {}

  ---@private
  function result.is_closing()
    return client.transport.is_closing()
  end

  ---@private
  function result.terminate()
    client.transport.terminate()
  end

  --- Sends a request to the BSP server and runs {callback} upon response.
  ---
  ---@param method (string) The invoked BSP method
  ---@param params (table?) Parameters for the invoked BSP method
  ---@param callback fun(err: bsp.ResponseError | nil, result: any) Callback to invoke
  ---@param notify_reply_callback (function?) Callback to invoke as soon as a request is no longer pending
  ---@return boolean success, integer? request_id true, message_id if request could be sent, `false` if not
  function result.request(method, params, callback, notify_reply_callback)
    return client:request(method, params, callback, notify_reply_callback)
  end

  --- Sends a notification to the BSP server.
  ---@param method (string) The invoked BSP method
  ---@param params (table?) Parameters for the invoked BSP method
  ---@return boolean `true` if notification could be sent, `false` if not
  function result.notify(method, params)
    return client:notify(method, params)
  end

  return result
end

---@param dispatchers bsp.rpc.Dispatchers?
---@return bsp.rpc.Dispatchers
local function merge_dispatchers(dispatchers)
  if dispatchers then
    local user_dispatchers = dispatchers
    dispatchers = {}
    for dispatch_name, default_dispatch in pairs(default_dispatchers) do
      ---@cast dispatch_name string
      ---@cast default_dispatch function
      local user_dispatcher = user_dispatchers[dispatch_name] --[[@as function]]
      if user_dispatcher then
        if type(user_dispatcher) ~= 'function' then
          error(string.format('dispatcher.%s must be a function', dispatch_name))
        end
        -- server_request is wrapped elsewhere.
        if
          not (dispatch_name == 'server_request' or dispatch_name == 'on_exit') -- TODO this blocks the loop exiting for some reason.
        then
          user_dispatcher = schedule_wrap(user_dispatcher)
        end
        dispatchers[dispatch_name] = user_dispatcher
      else
        dispatchers[dispatch_name] = default_dispatch
      end
    end
  else
    dispatchers = default_dispatchers
  end
  return dispatchers
end

--- Create a BSP RPC client factory that connects via TCP to the given host
--- and port
---
---@param host string host to connect to
---@param port integer port to connect to
---@return fun(dispatchers: bsp.rpc.Dispatchers): bsp.rpc.PublicRpcClient #function intended to be passed to |bsp.rpc.start_client| or |bsp.start| on the field cmd
function M.connect(host, port)
  return function(dispatchers)
    dispatchers = merge_dispatchers(dispatchers)
    local tcp = assert(uv.new_tcp(), string.format('could not connect to %s:%s', host, port))
    local closing = false
    local transport = {
      write = function(msg)
        tcp:write(msg)
      end,
      is_closing = function()
        return closing
      end,
      terminate = function()
        if not closing then
          closing = true
          tcp:shutdown()
          tcp:close()
          dispatchers.on_exit(0, 0)
        end
      end,
    }
    local client = new_client(dispatchers, transport)
    tcp:connect(host, port, function(err)
      if err then
        vim.schedule(function()
          vim.notify(
            string.format('Could not connect to %s:%s, reason: %s', host, port, vim.inspect(err)),
            vim.log.levels.WARN
          )
        end)
        return
      end
      local handle_body = function(body)
        client:handle_body(body)
      end
      tcp:read_start(M.create_read_loop(handle_body, transport.terminate, function(read_err)
        client:on_error(M.client_errors.READ_ERROR, read_err)
      end))
    end)

    return public_client(client)
  end
end

---@alias bsp.rpc.Dispatcher fun(method: string, params: table<string, any>):nil, bsp.rpc.RpcError?
---@alias bsp.rpc.on_error fun(code: integer, ...: any)
---@alias bsp.rpc.on_exit fun(code: integer, signal: integer)

---@class bsp.rpc.Dispatchers
---@field notification bsp.rpc.Dispatcher
---@field server_request bsp.rpc.Dispatcher
---@field on_exit bsp.rpc.on_error
---@field on_error bsp.rpc.on_exit

---@class bsp.rpc.PublicRpcClient
---@field request fun(method: string, params: table?, callback: fun(err: bsp.ResponseError | nil, result: any), notify_reply_callback:function?)
---@field notify fun(method: string, params: any)
---@field is_closing fun(): boolean
---@field terminate fun(): nil

--- Create a BSP RPC client factory that connects via named pipes (Windows)
--- or unix domain sockets (Unix) to the given pipe_path (file path on
--- Unix and name on Windows)
---
---@param pipe_path string file path of the domain socket (Unix) or name of the named pipe (Windows) to connect to
---@return fun(dispatchers: bsp.rpc.Dispatchers): bsp.rpc.PublicRpcClient #function intended to be passed to |bsp.rpc.start_client| or |bsp.start| on the field cmd
function M.connect_to_pipe(pipe_path)
  return function(dispatchers)
    dispatchers = merge_dispatchers(dispatchers)
    local pipe =
      assert(uv.new_pipe(false), string.format('pipe with name %s could not be opened.', pipe_path))
    local closing = false
    local transport = {
      write = vim.schedule_wrap(function(msg)
        pipe:write(msg)
      end),
      is_closing = function()
        return closing
      end,
      terminate = function()
        if not closing then
          closing = true
          pipe:shutdown()
          pipe:close()
          dispatchers.on_exit(0, 0)
        end
      end,
    }
    local client = new_client(dispatchers, transport)
    pipe:connect(pipe_path, function(err)
      if err then
        vim.schedule(function()
          vim.notify(
            string.format('Could not connect to :%s, reason: %s', pipe_path, vim.inspect(err)),
            vim.log.levels.WARN
          )
        end)
        return
      end
      local handle_body = function(body)
        client:handle_body(body)
      end
      pipe:read_start(M.create_read_loop(handle_body, transport.terminate, function(read_err)
        client:on_error(M.client_errors.READ_ERROR, read_err)
      end))
    end)

    return public_client(client)
  end
end

---@class bsp.rpc.ExtraSpawnParams
---@field cwd? string Working directory for the BSP server process
---@field detached? boolean Detach the BSP server process from the current process
---@field env? table<string,string> Additional environment variables for BSP server process. See |vim.system|

--- Starts an BSP server process and create an BSP RPC client object to
--- interact with it. Communication with the spawned process happens via stdio. For
--- communication via TCP, spawn a process manually and use |bsp.rpc.connect()|
---
---@param cmd (string) Command to start the BSP server.
---@param cmd_args (string[]) List of additional string arguments to pass to {cmd}.
---@param dispatchers bsp.rpc.Dispatchers? Dispatchers for BSP message types. Valid
---dispatcher names are:
--- - `"notification"`
--- - `"server_request"`
--- - `"on_error"`
--- - `"on_exit"`
---@param extra_spawn_params bsp.rpc.ExtraSpawnParams? Additional context for the BSP
--- server process. May contain:
--- - {cwd} (string) Working directory for the BSP server process
--- - {detached} (boolean?) Detach the BSP server process from the current process. Defaults to false on Windows and true otherwise.
--- - {env} (table?) Additional environment variables for BSP server process
---@return bsp.rpc.PublicRpcClient? #Client RPC object, with these methods:
--- - `notify()` |bsp.rpc.notify()|
--- - `request()` |bsp.rpc.request()|
--- - `is_closing()` returns a boolean indicating if the RPC is closing.
--- - `terminate()` terminates the RPC client.
function M.start(cmd, cmd_args, dispatchers, extra_spawn_params)
  if log.info() then
    log.info('Starting RPC client', { cmd = cmd, args = cmd_args, extra = extra_spawn_params })
  end

  validate({
    cmd = { cmd, 's' },
    cmd_args = { cmd_args, 't' },
    dispatchers = { dispatchers, 't', true },
  })

  extra_spawn_params = extra_spawn_params or {}

  if extra_spawn_params.cwd then
    assert(is_dir(extra_spawn_params.cwd), 'cwd must be a directory')
  end

  dispatchers = merge_dispatchers(dispatchers)

  local sysobj ---@type vim.SystemObj

  local client = new_client(dispatchers, {
    write = function(msg)
      sysobj:write(msg)
    end,
    is_closing = function()
      return sysobj == nil or sysobj:is_closing()
    end,
    terminate = function()
      sysobj:kill(15)
    end,
  })

  local handle_body = function(body)
    client:handle_body(body)
  end

  local stdout_handler = M.create_read_loop(handle_body, nil, function(err)
    client:on_error(M.client_errors.READ_ERROR, err)
  end)

  local stderr_handler = function(_, chunk)
    if chunk and log.error() then
      log.error('rpc', cmd, 'stderr', chunk)
    end
  end

  local detached = not is_win
  if extra_spawn_params.detached ~= nil then
    detached = extra_spawn_params.detached
  end

  local cmd1 = { cmd }
  vim.list_extend(cmd1, cmd_args)

  local ok, sysobj_or_err = pcall(vim.system, cmd1, {
    stdin = true,
    stdout = stdout_handler,
    stderr = stderr_handler,
    cwd = extra_spawn_params.cwd,
    env = extra_spawn_params.env,
    detach = detached,
  }, function(obj)
    dispatchers.on_exit(obj.code, obj.signal)
  end)

  if not ok then
    local err = sysobj_or_err --[[@as string]]
    local msg = string.format('Spawning language server with cmd: `%s` failed', cmd)
    if string.match(err, 'ENOENT') then
      msg = msg
        .. '. The language server is either not installed, missing from PATH, or not executable.'
    else
      msg = msg .. string.format(' with error message: %s', err)
    end
    vim.notify(msg, vim.log.levels.WARN)
    return
  end

  sysobj = sysobj_or_err --[[@as vim.SystemObj]]

  return public_client(client)
end

return M
