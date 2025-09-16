describe("Config", function()
	local config

	before_each(function()
		-- Set test mode flag for immediate XP processing
		_G._TEST_MODE = true

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

	it("should have default enhanced_statusline as false", function()
		local result = config.setup()
		assert.are.equal(false, result.enhanced_statusline)
	end)

	it("should allow setting enhanced_statusline through setup", function()
		local result = config.setup({
			enhanced_statusline = true,
		})
		assert.are.equal(true, result.enhanced_statusline)
	end)

	it("should have default statusline_format", function()
		local result = config.setup()
		assert.are.equal("%s%d (%d%% to L%d)", result.statusline_format)
	end)

	it("should allow custom statusline_format", function()
		local custom_format = "XP:%d L:%d [%d%%]"
		local result = config.setup({
			statusline_format = custom_format,
		})
		assert.are.equal(custom_format, result.statusline_format)
	end)

	it("should preserve enhanced statusline options with other config", function()
		local result = config.setup({
			api_key = "test_key",
			enhanced_statusline = true,
			statusline_format = "Custom: %s%d L%d (%d%%)",
		})
		assert.are.equal("test_key", result.api_key)
		assert.are.equal(true, result.enhanced_statusline)
		assert.are.equal("Custom: %s%d L%d (%d%%)", result.statusline_format)
	end)

	describe("notifications configuration", function()
		it("should have default notifications enabled", function()
			local result = config.setup()
			assert.are.equal(true, result.notifications.enabled)
			assert.are.equal(true, result.notifications.level_up.enabled)
			assert.are.equal("🎉 Level Up! %s reached level %d!", result.notifications.level_up.message)
		end)

		it("should allow disabling notifications", function()
			local result = config.setup({
				notifications = { enabled = false },
			})
			assert.are.equal(false, result.notifications.enabled)
		end)

		it("should allow disabling level-up notifications specifically", function()
			local result = config.setup({
				notifications = {
					enabled = true,
					level_up = { enabled = false },
				},
			})
			assert.are.equal(true, result.notifications.enabled)
			assert.are.equal(false, result.notifications.level_up.enabled)
		end)

		it("should allow custom level-up message", function()
			local custom_message = "Custom: %s advanced to level %d!"
			local result = config.setup({
				notifications = {
					level_up = { message = custom_message },
				},
			})
			assert.are.equal(custom_message, result.notifications.level_up.message)
		end)

		it("should preserve other config options when setting notifications", function()
			local result = config.setup({
				api_key = "test_key",
				status_prefix = "TEST ",
				notifications = { enabled = false },
			})
			assert.are.equal("test_key", result.api_key)
			assert.are.equal("TEST ", result.status_prefix)
			assert.are.equal(false, result.notifications.enabled)
		end)
	end)
end)
