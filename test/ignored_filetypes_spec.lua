describe("Ignored Filetypes", function()
	before_each(function()
		-- Mock plenary.curl before any module loading
		package.loaded["plenary.curl"] = {
			request = function(opts)
				if opts.callback then
					opts.callback({ status = 200 })
				end
				return { status = 200 }
			end,
		}

		-- Mock vim environment
		_G.vim = _G.vim or {}
		_G.vim.g = {}
		_G.vim.api = _G.vim.api or {}
		_G.vim.api.nvim_create_augroup = function()
			return 1
		end
		_G.vim.api.nvim_create_autocmd = function() end
		_G.vim.api.nvim_win_get_cursor = function()
			return { 1, 0 }
		end
		_G.vim.bo = { filetype = "lua" }
		_G.vim.fn = _G.vim.fn or {}
		_G.vim.fn.stdpath = function(what)
			if what == "data" then
				return "/tmp"
			end
			return "/tmp"
		end
		_G.vim.treesitter = {
			get_parser = function()
				error("No parser")
			end,
		}
		_G.vim.tbl_deep_extend = function(mode, ...)
			local result = {}
			for _, tbl in ipairs({ ... }) do
				if type(tbl) == "table" then
					for k, v in pairs(tbl) do
						if type(v) == "table" then
							result[k] = _G.vim.deepcopy(v)
						else
							result[k] = v
						end
					end
				end
			end
			return result
		end
		_G.vim.deepcopy = function(t)
			if type(t) == "table" then
				local copy = {}
				for k, v in pairs(t) do
					copy[k] = _G.vim.deepcopy(v)
				end
				return copy
			else
				return t
			end
		end

		-- Reset modules before each test
		package.loaded["maorun.code-stats.pulse"] = nil
		package.loaded["maorun.code-stats"] = nil
		package.loaded["maorun.code-stats.logging"] = nil
	end)

	it("should not add XP for ignored filetypes", function()
		local plugin = require("maorun.code-stats")
		local pulse = require("maorun.code-stats.pulse")

		pulse.reset()
		plugin.setup({ ignored_filetypes = { "markdown", "text", "log" } })

		plugin.add("markdown")
		plugin.add("text")
		plugin.add("log")

		assert.are.equal(0, pulse.getXp("markdown"))
		assert.are.equal(0, pulse.getXp("text"))
		assert.are.equal(0, pulse.getXp("log"))
	end)

	it("should add XP for non-ignored filetypes", function()
		local plugin = require("maorun.code-stats")
		local pulse = require("maorun.code-stats.pulse")

		pulse.reset()
		plugin.setup({ ignored_filetypes = { "markdown" } })

		plugin.add("lua")
		plugin.add("javascript")

		assert.are.equal(1, pulse.getXp("lua"))
		assert.are.equal(1, pulse.getXp("javascript"))
	end)
end)
