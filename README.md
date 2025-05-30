# Fixed space

> [!NOTE]
> Not adapted for public usability. Integrated into my personal setup.

> [!CAUTION]
> This document is not up to date. The plugin is hardcoded to support a left and a right panel.

Plugin to create a window to the right in NeoVim, not able to be resized. Meant as a fixed panel for whatever purpose...

Part of a solution for [mdtoc.nvim](https://github.com/fmxsh/mdtoc.nvim). _mdtoc.nvim_ sends its output to this.

In the future this may be developed into a more general purpose plugin.

Hardcoded features and such... not general purpose plugin yet...

## About the code

The code of this plugin was mainly boilerplate AI generated by ChatGPT 4o. It was then addapted in detail by hand...

## Installation

Integrated into my own project manager, to close and open on project switching.

This goes into `.config/nvim/lua/custom/plugins/fixedspace.lua`, which is loaded by my highly modified kickstart.lua running Lazy plugin manager.

> [!Note]
> This is not provided in a user friendly way and not expected to be used as it is. This is my highly specific setup. The plugin is not addapted for public use.

```lua
``return {
  'fmxsh/fixedspace.nvim',
  dependencies = {},
  config = function()
    require('fixedspace').setup {}

    vim.api.nvim_create_autocmd('User', {
      pattern = 'preSwitchToProject',
      callback = function()
        require('fixedspace').disable()
      end,
    })

    vim.api.nvim_create_autocmd('User', {
      pattern = 'postSwitchToProject',
      callback = function()
        require('fixedspace').enable()
        require('mdtoc').start()
      end,
    })
    vim.api.nvim_create_autocmd('User', {
      pattern = 'phxmPostLoaded',
      callback = function()
        require('fixedspace').enable()
      end,
    })
    vim.api.nvim_create_autocmd('User', {
      pattern = 'phxmPreSessionSave',
      callback = function()
        require('fixedspace').disable()
      end,
    })

    vim.api.nvim_create_autocmd('User', {
      pattern = 'phxmPostSessionSave',
      callback = function()
        require('fixedspace').enable()
      end,
    })
  end,
}
`
```
