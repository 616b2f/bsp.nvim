return {
  on_create_config = function (server_install_dir, workspace_dir)

      local connection_details = {
        name = "cargo-bsp",
        languages = { "rust" },
        version = "0.1.0",
        bspVersion = "2.1.0",
        argv = {
          server_install_dir .. '/packages/cargo-bsp/target/release/server'
        },
      }

      local bsp_dir_path = workspace_dir .. "/.bsp"
      vim.fn.mkdir(bsp_dir_path, "p")
      require("bsp").writeConnectionDetails(connection_details, bsp_dir_path .. "/cargo-bsp.json")
  end
}
