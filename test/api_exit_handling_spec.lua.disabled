describe("API Exit Handling", function()
	local api
	local pulse
	local original_io_open
	local mock_files = {}
	local original_vim_fn
	local api_calls = {}

	before_each(function()
		-- Reset modules
		package.loaded["maorun.code-stats.api"] = nil
		package.loaded["maorun.code-stats.pulse"] = nil
		package.loaded["maorun.code-stats.config"] = nil

		-- Mock vim environment
		_G.vim.fn = {
			stdpath = function(type)
				return "/tmp/test-nvim"
			end,
			json_encode = function(data)
				return vim.fn.json_encode(data)
			end,
			json_decode = function(str)
				return vim.fn.json_decode(str)
			end,
			delete = function(path)
				mock_files[path] = nil
			end,
			map = function(t, fn)
				local result = {}
				for k, v in pairs(t) do
					local mapped = fn(k, v)
					if mapped and mapped ~= "" then
						table.insert(result, mapped)
					end
				end
				return result
			end,
		}

		-- Mock io.open
		original_io_open = io.open
		io.open = function(path, mode)
			if mode == "w" then
				return {
					write = function(self, data)
						mock_files[path] = data
					end,
					close = function() end,
				}
			elseif mode == "r" then
				if mock_files[path] then
					return {
						read = function(self, format)
							return mock_files[path]
						end,
						close = function() end,
					}
				else
					return nil
				end
			end
			return original_io_open(path, mode)
		end

		-- Mock plenary.curl
		api_calls = {}
		package.loaded["plenary.curl"] = {
			request = function(opts)
				table.insert(api_calls, {
					url = opts.url,
					method = opts.method,
					body = opts.body,
					on_error = opts.on_error,
					callback = opts.callback,
				})

				-- Simulate behavior based on test needs
				local last_call = api_calls[#api_calls]
				last_call.trigger_error = function(message)
					if opts.on_error then
						opts.on_error({ message = message })
					end
				end
				last_call.trigger_success = function()
					if opts.callback then
						opts.callback({ status = 200 })
					end
				end

				return { status = 200 }
			end,
		}

		-- Clear mock state
		mock_files = {}
		api_calls = {}

		-- Load modules after mocking
		pulse = require("maorun.code-stats.pulse")
		api = require("maorun.code-stats.api")

		-- Setup config
		local config = require("maorun.code-stats.config")
		config.setup({ api_key = "test_key", api_url = "https://test.example.com/" })
	end)

	after_each(function()
		io.open = original_io_open
	end)

	it("should persist XP on API error during exit", function()
		-- Add some XP
		pulse.addXp("lua", 10)
		pulse.addXp("python", 5)

		-- Call pulseSendOnExit which should trigger API call
		api.pulseSendOnExit()

		-- Verify API was called
		assert.are.equal(1, #api_calls)
		assert.is_true(string.find(api_calls[1].body, "lua") ~= nil)

		-- Simulate API error
		api_calls[1].trigger_error("Connection failed")

		-- Verify XP was persisted
		local file_path = "/tmp/test-nvim/code-stats-xp.json"
		assert.is_not_nil(mock_files[file_path])

		local saved_data = vim.fn.json_decode(mock_files[file_path])
		assert.are.equal(10, saved_data.lua)
		assert.are.equal(5, saved_data.python)
	end)

	it("should reset XP on successful API call during exit", function()
		-- Add some XP
		pulse.addXp("lua", 10)

		-- Call pulseSendOnExit
		api.pulseSendOnExit()

		-- Simulate successful API call
		api_calls[1].trigger_success()

		-- Verify XP was reset and no persistence file created
		assert.are.equal(0, pulse.getXp("lua"))
		local file_path = "/tmp/test-nvim/code-stats-xp.json"
		assert.is_nil(mock_files[file_path])
	end)

	it("should clean up persistence file on exit when no XP to send", function()
		-- Create a persistence file
		local file_path = "/tmp/test-nvim/code-stats-xp.json"
		mock_files[file_path] = '{"lua":5}'

		-- Call pulseSendOnExit with no current XP
		api.pulseSendOnExit()

		-- Should have cleaned up the file even though no API call was made
		assert.is_nil(mock_files[file_path])
		assert.are.equal(0, #api_calls) -- No API call should be made
	end)

	it("should not persist XP on API error during normal pulseSend", function()
		-- Add some XP
		pulse.addXp("javascript", 8)

		-- Call normal pulseSend (not exit)
		api.pulseSend()

		-- Simulate API error
		api_calls[1].trigger_error("Connection failed")

		-- Verify XP was NOT persisted (because it's not an exit scenario)
		local file_path = "/tmp/test-nvim/code-stats-xp.json"
		assert.is_nil(mock_files[file_path])

		-- XP should still be in memory
		assert.are.equal(8, pulse.getXp("javascript"))
	end)

	it("should handle empty XP data during exit gracefully", function()
		-- No XP added

		-- Call pulseSendOnExit
		api.pulseSendOnExit()

		-- Should not make API call
		assert.are.equal(0, #api_calls)

		-- Should not create persistence file
		local file_path = "/tmp/test-nvim/code-stats-xp.json"
		assert.is_nil(mock_files[file_path])
	end)
end)
