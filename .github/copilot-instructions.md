# Code::Stats Neovim Plugin

Code::Stats integration plugin for Neovim written in Lua. This plugin tracks coding statistics and sends them to the Code::Stats service.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

### Bootstrap Development Environment
Run the following commands to set up the complete development environment:

```bash
# Run the development environment setup script (takes 3-5 minutes)
./install.sh
```

The install script will:
- Install Neovim (if not present)
- Install Luarocks package manager
- Install stylua (Lua code formatter)
- Install vusted (Neovim test runner)
- Install inspect (Lua inspection library)
- Set up proper PATH configuration

**TIMING**: Environment setup takes 3-7 minutes depending on what needs to be installed. NEVER CANCEL - wait for completion.

### Add Required PATH Export
After running install.sh, ensure the following is in your environment:
```bash
export PATH=$HOME/.luarocks/bin:$PATH
```

### Build and Lint
```bash
# Format and check Lua code (instant execution)
stylua --check .

# Auto-format Lua code if needed
stylua .
```

**TIMING**: Stylua formatting is instant (< 1 second).

### Run Tests
The CI pipeline uses vusted for testing. For development validation, use this comprehensive test:

```bash
# Run comprehensive functionality test (instant execution)
lua -e "
package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path
-- Mock vim environment
_G.vim = {
    g = {}, bo = { filetype = 'lua' },
    api = { 
        nvim_create_augroup = function(name) print('Created augroup:', name); return 1 end,
        nvim_create_autocmd = function(events) 
            local event_str = type(events) == 'table' and table.concat(events, ', ') or events
            print('Created autocmd for events:', event_str)
        end,
        nvim_win_get_cursor = function() return {1, 0} end
    },
    fn = { 
        map = function(t, fn) 
            local result = {}
            for k, v in pairs(t) do
                local mapped = fn(k, v)
                if mapped and mapped ~= '' then table.insert(result, mapped) end
            end
            return result
        end 
    },
    tbl_values = function(t) local v={}; for _,val in pairs(t) do table.insert(v,val) end; return v end,
    tbl_deep_extend = function(m,...) local r={}; for _,tbl in ipairs({...}) do for k,v in pairs(tbl) do r[k]=v end end; return r end,
    deepcopy = function(t) return type(t)=='table' and t or t end,
    treesitter = {
        get_parser = function() 
            error('No parser available') -- This will be caught by pcall
        end
    }
}
package.loaded['plenary.curl'] = { 
    request = function(opts) 
        print('API call to:', opts.url, 'Method:', opts.method)
        if opts.callback then opts.callback({status=200}) end
        return {status=200} 
    end 
}

-- Load and test plugin
local plugin = require('maorun.code-stats')
plugin.setup({api_key='test_key', status_prefix='CS '})
plugin.add('lua'); plugin.add('lua'); plugin.add('javascript')
print('Current XP:', plugin.currentXp())
plugin.pulseSend()
print('All comprehensive tests passed!')
"
```

**TIMING**: Comprehensive test executes instantly (< 1 second).

## Plugin Architecture

### Core Files Structure
```
lua/maorun/code-stats/
├── init.lua          # Main plugin entry point
├── config.lua        # Configuration management
├── pulse.lua         # XP tracking and management
├── api.lua           # Code::Stats API communication
└── events.lua        # Neovim autocommand setup
```

### Key Dependencies
- `plenary.nvim` - Required for HTTP requests to Code::Stats API
- Neovim 0.8.0+ - Plugin runtime environment

## Validation

### Always Run Before Committing
```bash
# 1. Format check (instant)
stylua --check .

# 2. Comprehensive functionality test (instant)  
lua -e "[comprehensive test script from above]"
```

### Complete Validation Workflow
Run this complete validation sequence before committing changes:
```bash
export PATH=$HOME/.luarocks/bin:$PATH
stylua --check .
lua -e "[comprehensive test script from above]"
echo "All validations passed - ready to commit!"
```

### Manual Testing Scenarios
After making changes, validate the plugin works by:

1. **Configuration Test**: Verify plugin setup accepts configuration
2. **XP Tracking Test**: Verify XP can be added and retrieved
3. **API Integration Test**: Verify API calls are properly formatted (mocked)
4. **Event Setup Test**: Verify autocommands are created without errors

### CI Pipeline Validation
The `.github/workflows/ci.yml` pipeline runs:
- **Lint Job**: Stylua formatting check and auto-commit
- **Test Job**: Matrix testing on Ubuntu and macOS with vusted
- **Docs Job**: Auto-generate documentation from README
- **Coverage Job**: Generate and commit coverage reports

Always run `stylua --check .` before committing to prevent CI failures.

## Common Tasks

### Adding New Features
1. Modify appropriate files in `lua/maorun/code-stats/`
2. Add corresponding tests in `test/` directory
3. Run validation commands
4. Test plugin loading in Neovim

### Debugging Issues
1. Check configuration in `config.lua`
2. Test XP tracking in `pulse.lua`
3. Verify API communication in `api.lua`
4. Check autocommand setup in `events.lua`

### Performance Considerations
- XP tracking happens on text changes and should be lightweight
- API calls are asynchronous and batched
- Plugin loads only when explicitly required

## Important Notes

- **File Types**: Plugin uses `vim.bo.filetype` to determine programming language
- **XP Persistence**: XP is tracked in memory and sent to API periodically
- **Error Handling**: API errors are captured and displayed in statusline
- **Configuration**: Requires valid Code::Stats API key for functionality

## Repository Structure Overview
```
.
├── .github/workflows/ci.yml    # CI pipeline configuration
├── .luacov                     # Lua coverage configuration  
├── .stylua.tom                 # Stylua formatter configuration
├── README.md                   # User documentation
├── doc/code-stats.nvim.txt     # Vim help documentation
├── install.sh                  # Development setup script
├── lua/maorun/code-stats/      # Main plugin source code
├── test/                       # Test files for vusted
└── renovate.json              # Dependency update configuration
```

### Development Workflow
1. Run `./install.sh` once to set up environment (3-7 minutes, NEVER CANCEL)
2. Make code changes in `lua/maorun/code-stats/`
3. Run `stylua --check .` to verify formatting (instant)
4. Run comprehensive functionality test (instant)
5. Test plugin loading manually if needed
6. Commit changes after validation

The plugin is designed to be lightweight and integrate seamlessly with the Neovim editing experience while providing accurate coding statistics to the Code::Stats service.