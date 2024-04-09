local validate = vim.validate

M = {}

-- local success, mason_registry = pcall(require, 'mason-registry')
-- local installed_packages = mason_registry.get_installed_package_names()

---Creates the build server configuration
---@param server_name string
---@param workspace_dir string
function M.create_config(server_name, workspace_dir)
  ---@type boolean, { on_create_config: fun(server_install_dir: string, workspace_dir: string) }
  local success, config = pcall(require, 'bsp-config.server_configurations.' .. server_name)
  if not success then
    error('bsp-config for "' .. server_name .. '" not found')
    return
  end

  validate {
    on_create_config = { config.on_create_config, 'f', true }
  }

  if config.on_create_config then
    local success, mason_path = pcall(require, 'mason-core.path')
    if not success then
      error('package mason-registry is not installed, it\'s mandatory for bsp-config')
      return
    end

    local server_install_dir = mason_path.package_prefix(server_name)
    pcall(config.on_create_config, server_install_dir, workspace_dir)
  end
end

return M
