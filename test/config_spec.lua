describe("Config", function()
	local config

	before_each(function()
		-- Reset the config module before each test
		package.loaded["maorun.code-stats.config"] = nil
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
