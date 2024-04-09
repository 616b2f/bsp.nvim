# bsp.nvim
Build Server Protocol  (BSP) client for Neovim. BSP is designed to allow your editor to communicate with different build tools to compile, run, test, debug your code and more. For more info see the [Official BSP specification](https://build-server-protocol.github.io/docs/specification).

This is currently in active development and is not stable. You are welcome to contibute and make PRs.

# Installation

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

```lua
require("bsp").setup()
```

## Setup BSP Server
you can use my fork of mason-registry to install bsp-servers (if there is enough interest I will create PRs for them upsream). For that you have to clone it first, e.g.:

```sh
$ cd ~/my-folder
$ git clone https://github.com/616b2f/mason-registry.git
```

Add the fork as additional registry, this will first look in the official repository and after that in my fork.
```lua
require("mason").setup({
  registries = {
    "github:mason-org/mason-registry",
    "file:~/my-folder/mason-registry", -- directory of the cloned fork
  }
})
```
After that go to the root of your project and run `BspCreateConfig <bsp_server_name>` you can use TAB to select between available server configurations. A config file `.bsp/<bsp_server_name.json` will be created for you. The server has to be installed for it to work.

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
```

# Credits
Thanks to the following projects that helped me to build this project.

- https://github.com/neovim/neovim I borrowed most of the implementation from the LSP implementation there.
- https://github.com/JetBrains/intellij-bsp To get an idea how the implementation could look like and how some of the methods are used to collect information about the workspace.
- https://github.com/microsoft/vscode-gradle Also for implementation details
