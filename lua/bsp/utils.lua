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

return M
