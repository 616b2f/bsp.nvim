---@class bsp.Console
---@field name string Name of the console
---@field buffer_number? integer Number of the buffer
local Console = {
  name = "[BSP console]",
  buffer_number = -1
}

local consoles_list = {}

---Create a new console instance
---@param console bsp.Console|nil
---@return bsp.Console
function Console:new(console)
  console = console or {}
  setmetatable(console, self)
  self.__index = self

  consoles_list[console.name] = console

  return console
end

---Write data to the console
---@param console bsp.Console 
---@param data string[]
function Console.write(console, data)
    vim.schedule(function()
      Console._create_buffer(console)
      if data then
          -- Make writable for short period, so we don't get warnings
          vim.api.nvim_set_option_value("readonly", false, { buf = console.buffer_number })

          vim.api.nvim_buf_set_lines(console.buffer_number, -1, -1, true, data)

          -- Make readonly again.
          vim.api.nvim_set_option_value("readonly", true, { buf = console.buffer_number })

      end
    end)
end

---@private
--- Create a buffer if it's not already there
function Console._create_buffer(console)
    -- local buffer_visible = vim.api.nvim_call_function("bufwinnr", { console.buffer_number }) ~= -1
    if console.buffer_number == -1 then
        -- Create a new buffer with the name "BSP_CONSOLE".
        -- Same name will reuse the current buffer.
        console.buffer_number = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_set_option_value('buftype', 'nofile', { buf = console.buffer_number })
        vim.api.nvim_set_option_value('modified', false, { buf = console.buffer_number })
        vim.api.nvim_buf_set_name(console.buffer_number, console.name)
        -- Mark the buffer as readonly.
        vim.api.nvim_set_option_value('readonly', true, { buf = console.buffer_number })
    end
end

---Open a console
---@param name string Name of the console to open
function Console.open(name)
    local console = consoles_list[name]
    assert(console, "console with the name: '" .. name .. "' not found")

    Console._create_buffer(console)
    local buffer_visible = vim.api.nvim_call_function("bufwinnr", { console.buffer_number }) ~= -1
    if not buffer_visible and console.buffer_number ~= -1 then
        vim.cmd('belowright split ' .. tostring(console.buffer_number))
        local win_number = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win_number, console.buffer_number)
        -- Get the window the buffer is in and set the cursor position to the bottom.
        -- local buffer_line_count = vim.api.nvim_buf_line_count(console.buffer_number)
        -- vim.api.nvim_win_set_cursor(buffer_window, { buffer_line_count, 0 })
    end
end

return Console
