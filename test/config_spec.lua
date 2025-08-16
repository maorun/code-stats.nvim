describe("Config", function()
	local config

	before_each(function()
		-- Mock vim environment before requiring modules
		_G.vim = _G.vim or {}
		_G.vim.g = {}
		_G.vim.fn = _G.vim.fn or {}
		_G.vim.fn.stdpath = function(what)
			if what == "data" then
				return "/tmp"
			end
			return "/tmp"
		end
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

		-- Reset the config module before each test
		package.loaded["maorun.code-stats.config"] = nil
		package.loaded["maorun.code-stats.logging"] = nil
		config = require("maorun.code-stats.config")
	end)

	it("should have default ignored_filetypes as empty table", function()
		local result = config.setup()
		assert.are.same({}, result.ignored_filetypes)
	end)

	it("should allow setting ignored_filetypes through setup", function()
		local result = config.setup({
			ignored_filetypes = { "markdown", "text", "log" },
		})
		assert.are.same({ "markdown", "text", "log" }, result.ignored_filetypes)
	end)

	it("should preserve other config options when setting ignored_filetypes", function()
		local result = config.setup({
			api_key = "test_key",
			status_prefix = "TEST ",
			ignored_filetypes = { "typescript" },
		})
		assert.are.equal("test_key", result.api_key)
		assert.are.equal("TEST ", result.status_prefix)
		assert.are.same({ "typescript" }, result.ignored_filetypes)
	end)

	it("should merge ignored_filetypes with defaults correctly", function()
		-- First setup with some ignored types
		config.setup({ ignored_filetypes = { "markdown" } })

		-- Setup again with different ignored types (should replace, not merge)
		local result = config.setup({ ignored_filetypes = { "typescript", "log" } })
		assert.are.same({ "typescript", "log" }, result.ignored_filetypes)
	end)
end)
