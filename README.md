# Code::Stats integration in lua

[Homepage of Code::Stats](https://codestats.net/) (The free stats tracking service for programmers)

## Installation
eg:
[vim-plug](https://github.com/junegunn/vim-plug)
```vim
Plug 'nvim-lua/plenary.nvim'
Plug('maorun/code-stats.nvim')
```

## Usage

you must set the api-key either trough the setup or as an global variable

in vim:
```vim
let g:codestats_api_key = '<YOUR_KEY>'
```
or lua:
```lua
vim.g.codestats_api_key = '<YOUR_KEY>'
```

now setup the plugin

```lua
require('maorun.code-stats').setup({
    api_key = '<YOUR_API_KEY>' -- not necessary if global api key is set
    status_prefix = 'C:S ' -- the prefix of xp in statusline
    ignored_filetypes = {'markdown', 'text'} -- filetypes to ignore from XP tracking
})
```

## Statusline
with ```require('maorun.code-stats').currentXp()``` you can get the current xp
of the buffer

```lua
vim.opt.statusline=vim.opt.statusline + "%{luaeval(\"require('maorun.code-stats').currentXp()\")} "
```

## User Commands

The plugin provides several user commands to access XP information:

### `:CodeStatsXP`
Shows XP for the currently detected language at cursor position.

### `:CodeStatsAll`
Shows XP for all tracked languages, sorted by XP amount (highest first).

### `:CodeStatsLang <language>`
Shows XP for a specific language. Supports tab completion with tracked languages.

**Example usage:**
```vim
:CodeStatsXP                " Show current language XP
:CodeStatsAll               " Show all languages with XP
:CodeStatsLang lua          " Show XP for Lua specifically
```

## Ignoring File Types

You can exclude specific file types from XP tracking by specifying them in the `ignored_filetypes` configuration option:

```lua
require('maorun.code-stats').setup({
    api_key = '<YOUR_API_KEY>',
    ignored_filetypes = {
        'markdown',    -- Don't track XP for markdown files
        'text',        -- Don't track XP for text files  
        'gitcommit',   -- Don't track XP for git commit messages
        'log'          -- Don't track XP for log files
    }
})
```

Changes to the ignored file types take effect immediately without requiring a restart of the editor.


## Troubleshooting
atm. the filetype is used as language because i don't know how to get the
language on actual input

(eg. CSS in HTML)
