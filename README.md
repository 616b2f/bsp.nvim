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

# Credits
Thanks to the following projects that helped me to build this project.

- https://github.com/neovim/neovim I borrowed most of the implementation from the LSP implementation there.
- https://github.com/JetBrains/intellij-bsp To get an idea how the implementation could look like and how some of the methods are used to collect information about the workspace.
- https://github.com/microsoft/vscode-gradle Also for implementation details
