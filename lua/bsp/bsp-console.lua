local M = {}

local buffer_number = -1

---Write data to the console
---@param data string[]
function M.write(data)
    vim.schedule(function()
      M._create()
      if data then
          -- Make writable for short period, so we don't get warnings
          vim.api.nvim_set_option_value("readonly", false, { buf = buffer_number })

          vim.api.nvim_buf_set_lines(buffer_number, -1, -1, true, data)

          -- Make readonly again.
          vim.api.nvim_set_option_value("readonly", true, { buf = buffer_number })

      end
    end)
end

---@private
--- Create a buffer if it's not already there
function M._create()
    -- local buffer_visible = vim.api.nvim_call_function("bufwinnr", { buffer_number }) ~= -1
    if buffer_number == -1 then
        -- Create a new buffer with the name "BSP_CONSOLE".
        -- Same name will reuse the current buffer.
        buffer_number = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_set_option_value('buftype', 'nofile', { buf = buffer_number })
        vim.api.nvim_set_option_value('modified', false, { buf = buffer_number })
        -- vim.api.nvim_buf_set_name(buffer_number, 'BSP_CONSOLE')
        -- Mark the buffer as readonly.
        vim.api.nvim_set_option_value('readonly', true, { buf = buffer_number })
    end
end

function M.open()
    local buffer_visible = vim.api.nvim_call_function("bufwinnr", { buffer_number }) ~= -1
    if not buffer_visible and buffer_number ~= -1 then
        vim.cmd('belowright split ' .. tostring(buffer_number))
        local win_number = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win_number, buffer_number)
        -- Get the window the buffer is in and set the cursor position to the bottom.
        -- local buffer_line_count = vim.api.nvim_buf_line_count(buffer_number)
        -- vim.api.nvim_win_set_cursor(buffer_window, { buffer_line_count, 0 })
    end
end

return M
