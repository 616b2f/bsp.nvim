local bsp = require('bsp')
local progress = require("fidget.progress")
local handles = {}
vim.api.nvim_create_autocmd("User",
  {
    group = 'bsp',
    pattern = 'BspProgress:start',
    callback = function(ev)
      local data = ev.data
      local client = bsp.get_client_by_id(data.client_id)
      if client then
        ---@type bsp.TaskStartParams
        local result = ev.data.result
        local title = result.dataKind or "BSP-Task"
        local fallback_message = "started: " .. tostring(result.taskId.id)
        local message = result.message or fallback_message;

        local tokenId = data.client_id .. ":" .. result.taskId.id
        handles[tokenId] = progress.handle.create({
          token = tokenId,
          title = title,
          message = message,
          lsp_client = { name = client.name }
        })
      end
    end
  })

vim.api.nvim_create_autocmd("User",
  {
    group = 'bsp',
    pattern = 'BspProgress:progress',
    callback = function(ev)
      local data = ev.data
      local percentage = nil
      ---@type bsp.TaskProgressParams
      local result = ev.data.result
      if data.result and data.result.message then
        local message =
          (data.result.originId and ( data.result.originId .. ': ') .. data.result.message)
          or data.result.message
        if data.result.total and data.result.progress then
          percentage = math.max(percentage or 0, (data.result.progress / data.result.total * 100))
        end

        local tokenId = data.client_id .. ":" .. result.taskId.id
        local handle = handles[tokenId]
        if handle then
            local progressMessage = {
              token = tokenId,
              message = message,
              percentage = percentage
            }
            handle:report(progressMessage)
        end
      end
    end
  })

vim.api.nvim_create_autocmd("User",
  {
    group = 'bsp',
    pattern = 'BspProgress:finish',
    callback = function(ev)
      local data = ev.data
      ---@type bsp.TaskFinishParams
      local result = ev.data.result
      local tokenId = data.client_id .. ":" .. result.taskId.id
      local handle = handles[tokenId]
      if handle then
        handle:finish()
      end
    end
  })
