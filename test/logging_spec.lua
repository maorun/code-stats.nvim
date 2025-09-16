describe("Logging", function()
	-- Set test mode flag for immediate XP processing
	_G._TEST_MODE = true

	local logging

	before_each(function()
		-- Mock vim environment
		_G.vim = _G.vim or {}
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
		_G.vim.fn = _G.vim.fn or {}
		_G.vim.fn.stdpath = function(what)
			if what == "data" then
				return "/tmp"
			end
			return "/tmp"
		end

		-- Reset the logging module before each test
		package.loaded["maorun.code-stats.logging"] = nil
		logging = require("maorun.code-stats.logging")
	end)

	it("should initialize with disabled logging by default", function()
		assert.is_false(logging.is_enabled())
	end)

	it("should configure logging when setup is called", function()
		logging.setup({
			enabled = true,
			level = logging.levels.DEBUG,
			file_path = "/tmp/test.log",
		})

		assert.is_true(logging.is_enabled())
		assert.are.equal("/tmp/test.log", logging.get_log_file())
	end)

	it("should set default log file path when enabled but no path provided", function()
		logging.setup({
			enabled = true,
		})

		assert.is_true(logging.is_enabled())
		assert.are.equal("/tmp/code-stats.log", logging.get_log_file())
	end)

	it("should provide log level constants", function()
		assert.are.equal(1, logging.levels.ERROR)
		assert.are.equal(2, logging.levels.WARN)
		assert.are.equal(3, logging.levels.INFO)
		assert.are.equal(4, logging.levels.DEBUG)
	end)

	it("should provide logging functions", function()
		assert.is_function(logging.error)
		assert.is_function(logging.warn)
		assert.is_function(logging.info)
		assert.is_function(logging.debug)
		assert.is_function(logging.log_api_request)
		assert.is_function(logging.log_xp_operation)
		assert.is_function(logging.log_config)
		assert.is_function(logging.log_init)
	end)

	it("should not write to file when logging is disabled", function()
		-- Mock io.open to track calls
		local file_opened = false
		local original_io_open = io.open
		io.open = function()
			file_opened = true
			return nil
		end

		logging.setup({ enabled = false })
		logging.error("test message")

		assert.is_false(file_opened)

		-- Restore original function
		io.open = original_io_open
	end)

	it("should write to file when logging is enabled", function()
		-- Mock io.open to simulate successful file writing
		local written_content = ""
		local original_io_open = io.open
		io.open = function(path, mode)
			if mode == "a" then
				return {
					write = function(self, content)
						written_content = written_content .. content
					end,
					close = function() end,
				}
			end
			return nil
		end

		logging.setup({
			enabled = true,
			level = logging.levels.INFO,
			file_path = "/tmp/test.log",
		})
		logging.error("test error message")

		assert.is_truthy(written_content:match("ERROR.*test error message"))

		-- Restore original function
		io.open = original_io_open
	end)

	it("should respect log level filtering", function()
		local written_content = ""
		local original_io_open = io.open
		io.open = function(path, mode)
			if mode == "a" then
				return {
					write = function(self, content)
						written_content = written_content .. content
					end,
					close = function() end,
				}
			end
			return nil
		end

		-- Set log level to WARN (should filter out INFO and DEBUG)
		logging.setup({
			enabled = true,
			level = logging.levels.WARN,
			file_path = "/tmp/test.log",
		})

		logging.debug("debug message")
		logging.info("info message")
		logging.warn("warn message")
		logging.error("error message")

		-- Should only contain WARN and ERROR messages
		assert.is_truthy(written_content:match("WARN.*warn message"))
		assert.is_truthy(written_content:match("ERROR.*error message"))
		assert.is_falsy(written_content:match("DEBUG.*debug message"))
		assert.is_falsy(written_content:match("INFO.*info message"))

		-- Restore original function
		io.open = original_io_open
	end)

	it("should format API request logs correctly", function()
		local written_content = ""
		local original_io_open = io.open
		io.open = function(path, mode)
			if mode == "a" then
				return {
					write = function(self, content)
						written_content = written_content .. content
					end,
					close = function() end,
				}
			end
			return nil
		end

		logging.setup({
			enabled = true,
			level = logging.levels.INFO,
			file_path = "/tmp/test.log",
		})

		logging.log_api_request("https://example.com", "POST", true)
		logging.log_api_request("https://example.com", "POST", false, "Connection error")

		assert.is_truthy(written_content:match("API POST https://example.com %- SUCCESS"))
		assert.is_truthy(written_content:match("API POST https://example.com %- FAILED %- Connection error"))

		-- Restore original function
		io.open = original_io_open
	end)

	it("should format XP operation logs correctly", function()
		local written_content = ""
		local original_io_open = io.open
		io.open = function(path, mode)
			if mode == "a" then
				return {
					write = function(self, content)
						written_content = written_content .. content
					end,
					close = function() end,
				}
			end
			return nil
		end

		logging.setup({
			enabled = true,
			level = logging.levels.INFO,
			file_path = "/tmp/test.log",
		})

		logging.log_xp_operation("ADD", "lua", 1, 5)

		assert.is_truthy(written_content:match("XP ADD: lua %+1 %(total: 5%)"))

		-- Restore original function
		io.open = original_io_open
	end)

	it("should handle clear log function", function()
		local file_cleared = false
		local original_io_open = io.open
		io.open = function(path, mode)
			if mode == "w" then
				file_cleared = true
				return {
					close = function() end,
				}
			end
			return nil
		end

		logging.setup({
			enabled = true,
			file_path = "/tmp/test.log",
		})
		logging.clear_log()

		assert.is_true(file_cleared)

		-- Restore original function
		io.open = original_io_open
	end)
end)
