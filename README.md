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
    api_key = '<YOUR_API_KEY>', -- not necessary if global api key is set
    status_prefix = 'C:S ', -- the prefix of xp in statusline
    enhanced_statusline = false, -- Show XP, level and progress in statusline
    statusline_format = "%s%d (%d%% to L%d)", -- Format for enhanced statusline
    ignored_filetypes = {'markdown', 'text'}, -- filetypes to ignore from XP tracking
    logging = {
        enabled = false, -- Set to true to enable logging
        level = 'INFO', -- Log level: ERROR, WARN, INFO, DEBUG
        file_path = nil -- Optional custom log file path (defaults to vim data dir)
    }
})
```

## Statusline
with ```require('maorun.code-stats').currentXp()``` you can get the current xp
of the buffer

```lua
vim.opt.statusline=vim.opt.statusline + "%{luaeval(\"require('maorun.code-stats').currentXp()\")} "
```

### Enhanced Statusline

You can enable an enhanced statusline that shows XP, level, and progress to the next level:

```lua
require('maorun.code-stats').setup({
    api_key = '<YOUR_API_KEY>',
    enhanced_statusline = true,  -- Enable enhanced display
    statusline_format = "%s%d (%d%% to L%d)"  -- Optional: customize format
})
```

The enhanced statusline displays:
- Current XP for the active language
- Current level (calculated from XP)
- Progress percentage to the next level
- Next level number

**Format placeholders:**
- `%s` - Status prefix (default: "C:S ")
- First `%d` - Current XP
- Second `%d` - Progress percentage (0-100)
- Third `%d` - Next level number

**Example output:** `C:S 250 (25% to L3)` (250 XP, 25% progress to level 3)

You can also use the enhanced function directly:

```lua
vim.opt.statusline=vim.opt.statusline + "%{luaeval(\"require('maorun.code-stats').currentXpEnhanced()\")} "
```

**Level Calculation:** Levels are calculated using the formula `Level = floor(sqrt(XP / 100)) + 1`, where each level requires progressively more XP.

## User Commands

The plugin provides several user commands to access XP information:

### `:CodeStatsXP`
Shows XP for the currently detected language at cursor position.

### `:CodeStatsAll`
Shows XP for all tracked languages, sorted by XP amount (highest first).

### `:CodeStatsLang <language>`
Shows XP for a specific language. Supports tab completion with tracked languages.

### `:CodeStatsXpSend`
Manually send all pending XP to Code::Stats immediately. This command provides:
- Immediate transmission of all tracked XP data
- Success confirmation when XP is sent successfully
- Error messages if transmission fails (network issues, invalid API key, etc.)

### `:CodeStatsLog [action]`
Manage logging functionality:
- `:CodeStatsLog status` - Show current logging status and log file location
- `:CodeStatsLog path` - Show log file path
- `:CodeStatsLog clear` - Clear the log file

**Example usage:**
```vim
:CodeStatsXP                " Show current language XP
:CodeStatsAll               " Show all languages with XP
:CodeStatsLang lua          " Show XP for Lua specifically
:CodeStatsXpSend            " Send all pending XP immediately
:CodeStatsLog status        " Show logging status
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

## Logging and Error Handling

The plugin includes comprehensive logging and error handling features to help track plugin activity and diagnose issues.

### Enabling Logging

To enable logging, configure the plugin with logging options:

```lua
require('maorun.code-stats').setup({
    api_key = '<YOUR_API_KEY>',
    logging = {
        enabled = true,           -- Enable logging
        level = 'INFO',          -- Log level: ERROR, WARN, INFO, DEBUG
        file_path = nil          -- Optional: custom log file path
    }
})
```

### Log Levels

- **ERROR**: Critical errors that prevent functionality
- **WARN**: Warning messages for non-critical issues
- **INFO**: General information about plugin operations
- **DEBUG**: Detailed debugging information

### Log File Location

By default, the log file is stored at `{vim.fn.stdpath("data")}/code-stats.log`. You can specify a custom location using the `file_path` option.

### Managing Logs

Use the `:CodeStatsLog` command to manage logging:

```vim
:CodeStatsLog status        " Show logging status and file location
:CodeStatsLog path          " Show log file path
:CodeStatsLog clear         " Clear the log file
```

### Error Messages

The plugin provides clear, user-friendly error messages for common issues:

- Configuration problems (missing API key, invalid URL)
- Network connectivity issues
- File I/O errors for XP persistence
- JSON parsing errors

Error messages are displayed in the statusline and through notifications, with detailed information logged to the log file when logging is enabled.


## Troubleshooting
atm. the filetype is used as language because i don't know how to get the
language on actual input

(eg. CSS in HTML)
