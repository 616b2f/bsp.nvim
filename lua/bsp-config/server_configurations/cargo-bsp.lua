return {
  on_create_config = function (server_install_dir, workspace_dir)
      local cmd = server_install_dir .. "/install.sh " .. workspace_dir
      local handle = io.popen(cmd)
      if handle then
        local output = handle:read('*a')
        if output then
          print("bsp-config install cargo-bsp config: " .. output)
        end
        handle:close()
      end
    end
}
