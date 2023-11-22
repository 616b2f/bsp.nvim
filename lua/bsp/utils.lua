local M = {}

---Find file by patterns
--
---@param source string
---@param patterns table
---@return string
function M.find_file_by_patterns(source, patterns)
  local ctx = {
    name = vim.fn.fnamemodify(source, ":t:r"),
    ext = vim.fn.fnamemodify(source, ":e"),
  }
  for _, pat in ipairs(patterns) do
    local filename = M.format_pattern(pat, ctx)
    local testfile = vim.fn.findfile(filename, source .. ";")
    if #testfile > 0 then
      return testfile
    end
  end
  -- if force then
  --   return vim.fn.fnamemodify(source, ":h") .. "/" .. M.format_pattern(patterns[1], ctx)
  -- end
  return source
end

function M.domain_socket_connect(pipe_path)
  return function(dispatchers)
    dispatchers = vim.rpc.merge_dispatchers(dispatchers)
    local pipe =
      assert(vim.uv.new_pipe(false), string.format('pipe with name %s could not be opened.', pipe_path))
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
    local client = vim.rpc.new_client(dispatchers, transport)
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

    return vim.rpc.public_client(client)
  end
end

return M
