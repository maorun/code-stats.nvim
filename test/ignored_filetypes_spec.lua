describe("Ignored Filetypes", function()
	local plugin
	local pulse

	before_each(function()
		-- Reset modules before each test
		package.loaded["maorun.code-stats.pulse"] = nil
		package.loaded["maorun.code-stats.config"] = nil
		package.loaded["maorun.code-stats.init"] = nil

		pulse = require("maorun.code-stats.pulse")

		-- Mock vim environment for init.lua
		_G.vim = _G.vim or {}
		_G.vim.api = _G.vim.api or {}
		_G.vim.api.nvim_create_augroup = function()
			return 1
		end
		_G.vim.api.nvim_create_autocmd = function() end
		_G.vim.api.nvim_win_get_cursor = function()
			return { 1, 0 }
		end
		_G.vim.bo = { filetype = "lua" }
		_G.vim.treesitter = {
			get_parser = function()
				error("No parser")
			end,
		}
		_G.vim.tbl_deep_extend = function(mode, ...)
			local result = {}
			for _, tbl in ipairs({ ... }) do
				for k, v in pairs(tbl) do
					result[k] = v
				end
			end
			return result
		end
		_G.vim.deepcopy = function(t)
			return t
		end

		plugin = require("maorun.code-stats")
	end)

	it("should add XP for non-ignored filetypes", function()
		plugin.setup({ ignored_filetypes = { "markdown" } })

		plugin.add("lua")
		plugin.add("javascript")

		assert.are.equal(1, pulse.getXp("lua"))
		assert.are.equal(1, pulse.getXp("javascript"))
	end)

	it("should not add XP for ignored filetypes", function()
		plugin.setup({ ignored_filetypes = { "markdown", "text", "log" } })

		plugin.add("markdown")
		plugin.add("text")
		plugin.add("log")

		assert.are.equal(0, pulse.getXp("markdown"))
		assert.are.equal(0, pulse.getXp("text"))
		assert.are.equal(0, pulse.getXp("log"))
	end)

	it("should work with mixed ignored and non-ignored filetypes", function()
		plugin.setup({ ignored_filetypes = { "markdown", "log" } })

		plugin.add("lua") -- should be tracked
		plugin.add("markdown") -- should be ignored
		plugin.add("python") -- should be tracked
		plugin.add("log") -- should be ignored
		plugin.add("javascript") -- should be tracked

		assert.are.equal(1, pulse.getXp("lua"))
		assert.are.equal(0, pulse.getXp("markdown"))
		assert.are.equal(1, pulse.getXp("python"))
		assert.are.equal(0, pulse.getXp("log"))
		assert.are.equal(1, pulse.getXp("javascript"))
	end)

	it("should allow empty ignored_filetypes (default behavior)", function()
		plugin.setup({ ignored_filetypes = {} })

		plugin.add("markdown")
		plugin.add("text")
		plugin.add("lua")

		assert.are.equal(1, pulse.getXp("markdown"))
		assert.are.equal(1, pulse.getXp("text"))
		assert.are.equal(1, pulse.getXp("lua"))
	end)

	it("should work when ignored_filetypes is not specified", function()
		plugin.setup({}) -- No ignored_filetypes specified

		plugin.add("markdown")
		plugin.add("lua")

		assert.are.equal(1, pulse.getXp("markdown"))
		assert.are.equal(1, pulse.getXp("lua"))
	end)

	it("should update ignored filetypes when setup is called again", function()
		-- First setup with some ignored types
		plugin.setup({ ignored_filetypes = { "markdown" } })
		plugin.add("markdown")
		plugin.add("lua")
		assert.are.equal(0, pulse.getXp("markdown"))
		assert.are.equal(1, pulse.getXp("lua"))

		-- Reset XP for clean test
		pulse.reset()

		-- Second setup with different ignored types
		plugin.setup({ ignored_filetypes = { "lua" } })
		plugin.add("markdown") -- should now be tracked
		plugin.add("lua") -- should now be ignored

		assert.are.equal(1, pulse.getXp("markdown"))
		assert.are.equal(0, pulse.getXp("lua"))
	end)
end)
