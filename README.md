# bsp.nvim
Build Server Protocol  (BSP) client for Neovim. BSP is designed to allow your editor to communicate with different build tools to compile, run, test, debug your code and more. For more info see the [Official BSP specification](https://build-server-protocol.github.io/docs/specification).

This is currently in active development and is not stable. You are welcome to contibute and make PRs.

# Installation

min supported neovim version is 0.10

## [Packer](https://github.com/wbthomason/packer.nvim)

```lua
use {
    "616b2f/bsp.nvim"
}
```

## [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "616b2f/bsp.nvim"
}
```

## [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug '616b2f/bsp.nvim'
```

# Setup
minimal setup
```lua
local bsp = require("bsp")
bsp.setup({})
```
the default config is used then

```lua
-- config defaults
bsp.setup({
  log = {
    -- use like
    -- level = vim.log.levels.DEBUG
    level = nil
  },
  ui = {
    -- adds additional ui handlers (currently mainly for test results pop-up)
    enable = false
  },
  on_start = {
    -- triggeres test case discovery when the server starts
    test_case_discovery = false
  },
  plugins = {
    -- enable Fidget plugin for BSP task notifications
    fidget = false
  },
  -- default handlers, change only if you wan't to override
  handlers = {

    ['cargo-bsp'] = function (workspace_dir, connection_details)
      -- cargo.toml in the current workspace (non recursive)
      for name, type in vim.fs.dir(workspace_dir) do
          if (type == "file") and
             name:match('^cargo.toml$') then
            return true
          end
      end

      return false
    end,

    ['gradle-bsp'] = function (workspace_dir, connection_details)
      -- gradle or gradlew.bat in the current workspace (non recursive)
      for name, type in vim.fs.dir(workspace_dir) do
          if (type == "file") and
             (name:match('^gradlew$') or name:match('^gradlew.bat$')) then
            return true
          end
      end

      return false
    end,

    ['dotnet-bsp'] = function (workspace_dir, connection_details)
      -- *.csproj or *.sln in the current workspace (non recursive)
      for name, type in vim.fs.dir(workspace_dir) do
          if (type == "file") and
             (name:match('.*.sln$') or name:match('.*.csproj$')) then
            return true
          end
      end

      return false
    end,

    ['*'] = function (workspace_dir, connection_details)
      -- .bsp/*.json
      for name, type in vim.fs.dir(workspace_dir .. "/.bsp/") do
          if (type == "file") and
             name:match('^.*%.json$') then
            return true
          end
      end

      return false
    end
  }
})
```

## Setup BSP Server
you can use my fork of mason-registry to install bsp-servers (if there is enough interest I will create PRs for them upsream). For that you have to clone it first, e.g.:

Add the fork as additional registry, this will first look in the official repository and after that in my fork.
```lua
require("mason").setup({
  registries = {
    "github:mason-org/mason-registry",
    "github:616b2f/mason-registry-bsp",
  }
})
```
## Create config
After the setup you have to create a config file for your BSP Server, that is located in the root of your project. To create the config file run `BspCreateConfig <bsp_server_name>` you can use TAB to select between available server configurations. A config file `.bsp/<bsp_server_name.json` will be created for you. The server has to be installed for it to work.

# Available commands

```sh
BspCleanCache
BspCompile
BspConsole
BspCreateConfig <bsp_server_name> # requires "mason-registry" package to be installed
BspInfo
BspLog
BspRestart
BspRun
BspTest
BspTestCase (workes only with dotnet-bsp server)
BspTestFile (workes only with dotnet-bsp server)
```

# Configuration Recipes

## Define keybindings on BspAttach
```lua
vim.api.nvim_create_autocmd("User",
{
  group = 'bsp',
  pattern = 'BspAttach',
  callback = function()
    local opts = {}
    vim.keymap.set('n', '<leader>bb', require('bsp').compile_build_target, opts)
    vim.keymap.set('n', '<leader>bt', require('bsp').test_build_target, opts)
    vim.keymap.set('n', '<leader>bc', require('bsp').cleancache_build_target, opts)
  end
})
```

# Credits
Thanks to the following projects that helped me to build this project.

- https://github.com/neovim/neovim I borrowed most of the implementation from the LSP implementation there.
- https://github.com/JetBrains/intellij-bsp To get an idea how the implementation could look like and how some of the methods are used to collect information about the workspace.
- https://github.com/microsoft/vscode-gradle Also for implementation details
