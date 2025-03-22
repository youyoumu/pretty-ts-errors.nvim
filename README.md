# pretty-ts-errors.nvim

A Neovim plugin that enhances TypeScript errors by formatting them into readable, markdown-formatted.



https://github.com/user-attachments/assets/e89fe22b-d1a3-464b-ac44-53f7372cb46f



## Requirements

- `pretty-ts-errors-markdown` executable in PATH ([install instructions](#installing-the-cli-tool))

## Installation

### With [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
-- pretty-ts-errors.lua
return {
  {
    "youyoumu/pretty-ts-errors.nvim",
    opts = {
      -- your configuration options
    },
  },
}
```

## Installing the CLI Tool

The plugin requires the `pretty-ts-errors-markdown` CLI tool. You can install it using npm:

```bash
npm install -g pretty-ts-errors-markdown
```

## Configuration

Here's the default configuration:

```lua
{
  executable = "pretty-ts-errors-markdown", -- Path to the executable
  float_opts = {
    border = "rounded",        -- Border style for floating windows
    max_width = 80,            -- Maximum width of floating windows
    max_height = 20,           -- Maximum height of floating windows
  },
  auto_open = true,            -- Automatically show errors on hover
}
```

## Usage

### Commands

The plugin provides the following commands:

- `:PrettyTsError` - Show the formatted error under the cursor in a floating window
- `:PrettyTsErrors` - Open a split window with all TypeScript errors in the current buffer
- `:PrettyTsToggleAuto` - Toggle automatic error display on hover

### Keybindings

Add these to your configuration:

```lua
-- Show error under cursor
vim.keymap.set('n', '<leader>te', function() require('pretty-ts-errors').show_formatted_error() end, { desc = "Show TS error" })

-- Show all errors in file
vim.keymap.set('n', '<leader>tE', function() require('pretty-ts-errors').open_all_errors() end, { desc = "Show all TS errors" })

-- Toggle auto-display
vim.keymap.set('n', '<leader>tt', function() require('pretty-ts-errors').toggle_auto_open() end, { desc = "Toggle TS error auto-display" })
```

## How It Works

The plugin intercepts TypeScript diagnostics from the LSP server and passes them to the CLI tool, which formats them into readable markdown. This markdown is then displayed in Neovim using floating windows or buffer splits.

## Credits

This project is powered by and inspired by:

- [pretty-ts-errors](https://github.com/yoavbls/pretty-ts-errors) - The original VS Code extension that improves TypeScript error messages
- [pretty-ts-errors-markdown](https://github.com/hexh250786313/pretty-ts-errors-markdown) - A fork of pretty-ts-errors that outputs errors in markdown format, which this plugin uses as a CLI dependency

Thanks to the original authors for creating these fantastic tools that make working with TypeScript more pleasant!


## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
