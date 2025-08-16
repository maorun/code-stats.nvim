describe("User Commands", function()
	local plugin
	local pulse

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
		_G.vim.api.nvim_create_user_command = function() end
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
		_G.vim.notify = function(msg, level, opts)
			return msg
		end
		_G.vim.log = { levels = { INFO = 1 } }
		_G.vim.fn = _G.vim.fn or {}
		_G.vim.fn.stdpath = function(what)
			if what == "data" then
				return "/tmp"
			end
			return "/tmp"
		end
		_G.vim.fn.json_decode = function(data)
			-- Simple JSON decoder for test data
			if type(data) == "string" and string.match(data, "^{.*}$") then
				-- Mock decode for test profile data
				if string.match(data, "testuser") then
					return {
						user = { username = "testuser" },
						total_xp = 12345,
						level = 25,
						languages = { lua = 5000, javascript = 3000 },
					}
				end
			end
			return {}
		end

		-- Reset modules before each test
		package.loaded["maorun.code-stats.pulse"] = nil
		package.loaded["maorun.code-stats"] = nil
		pulse = require("maorun.code-stats.pulse")
		plugin = require("maorun.code-stats")
	end)

	it("should provide getCurrentLanguageXP function", function()
		plugin.setup({ api_key = "test" })
		pulse.reset()

		plugin.add("lua")
		plugin.add("lua")

		local result = plugin.getCurrentLanguageXP()
		assert.is.truthy(string.match(result, "Language: lua, XP: 2"))
	end)

	it("should provide getAllLanguagesXP function", function()
		plugin.setup({ api_key = "test" })
		pulse.reset()

		plugin.add("lua")
		plugin.add("javascript")
		plugin.add("python")

		local result = plugin.getAllLanguagesXP()
		assert.is.truthy(string.match(result, "Tracked languages and XP:"))
		assert.is.truthy(string.match(result, "lua: 1 XP"))
		assert.is.truthy(string.match(result, "javascript: 1 XP"))
		assert.is.truthy(string.match(result, "python: 1 XP"))
	end)

	it("should sort languages by XP in getAllLanguagesXP", function()
		plugin.setup({ api_key = "test" })
		pulse.reset()

		-- Add different amounts of XP
		plugin.add("python")
		plugin.add("lua")
		plugin.add("lua")
		plugin.add("javascript")
		plugin.add("javascript")
		plugin.add("javascript")

		local result = plugin.getAllLanguagesXP()
		-- Check that javascript (3 XP) comes before lua (2 XP) which comes before python (1 XP)
		local js_pos = string.find(result, "javascript: 3 XP")
		local lua_pos = string.find(result, "lua: 2 XP")
		local py_pos = string.find(result, "python: 1 XP")

		assert.is.truthy(js_pos)
		assert.is.truthy(lua_pos)
		assert.is.truthy(py_pos)
		assert.is.truthy(js_pos < lua_pos)
		assert.is.truthy(lua_pos < py_pos)
	end)

	it("should provide getLanguageXP function", function()
		plugin.setup({ api_key = "test" })
		pulse.reset()

		plugin.add("lua")
		plugin.add("lua")

		local result = plugin.getLanguageXP("lua")
		assert.is.truthy(string.match(result, "Language: lua, XP: 2"))

		local result_unknown = plugin.getLanguageXP("unknown")
		assert.is.truthy(string.match(result_unknown, "Language: unknown, XP: 0"))
	end)

	it("should handle empty language parameter in getLanguageXP", function()
		plugin.setup({ api_key = "test" })

		local result = plugin.getLanguageXP("")
		assert.is.truthy(string.match(result, "Error: No language specified"))

		local result_nil = plugin.getLanguageXP(nil)
		assert.is.truthy(string.match(result_nil, "Error: No language specified"))
	end)

	it("should handle no tracked languages in getAllLanguagesXP", function()
		plugin.setup({ api_key = "test" })
		pulse.reset()

		local result = plugin.getAllLanguagesXP()
		assert.is.truthy(string.match(result, "No XP tracked yet"))
	end)

	-- Test the new profile functionality
	it("should provide profile functionality through API", function()
		-- Mock the API to simulate profile response
		local original_curl = package.loaded["plenary.curl"]
		package.loaded["plenary.curl"] = {
			request = function(opts)
				if opts.method == "GET" and string.match(opts.url, "profile") then
					local mock_profile =
						'{"user":{"username":"testuser"},"total_xp":12345,"level":25,"languages":{"lua":5000,"javascript":3000}}'
					if opts.callback then
						opts.callback({ status = 200, body = mock_profile })
					end
					return { status = 200, body = mock_profile }
				else
					if opts.callback then
						opts.callback({ status = 200 })
					end
					return { status = 200 }
				end
			end,
		}

		plugin.setup({ api_key = "test" })

		-- Mock vim.notify to capture the output
		local notify_called = false
		local notify_message = ""
		_G.vim.notify = function(msg, level, opts)
			notify_called = true
			notify_message = msg
		end

		-- Mock the profile command execution
		local api = require("maorun.code-stats.api")
		api.getProfile(function(profile_data, error_msg)
			assert.is.falsy(error_msg)
			assert.is.truthy(profile_data)

			-- Parse the JSON response
			local ok, profile = pcall(_G.vim.fn.json_decode, profile_data)
			assert.is.truthy(ok)
			assert.is.truthy(profile.user)
			assert.are.equal("testuser", profile.user.username)
			assert.are.equal(12345, profile.total_xp)
			assert.are.equal(25, profile.level)
		end)

		-- Restore original curl mock
		package.loaded["plenary.curl"] = original_curl
	end)

	it("should handle profile API errors gracefully", function()
		-- Mock the API to simulate error response
		local original_curl = package.loaded["plenary.curl"]
		package.loaded["plenary.curl"] = {
			request = function(opts)
				if opts.on_error then
					opts.on_error({ message = "Network error" })
				end
				return nil
			end,
		}

		plugin.setup({ api_key = "test" })

		-- Test error handling
		local api = require("maorun.code-stats.api")
		api.getProfile(function(profile_data, error_msg)
			assert.is.falsy(profile_data)
			assert.is.truthy(error_msg)
			assert.is.truthy(string.match(error_msg, "Network error"))
		end)

		-- Restore original curl mock
		package.loaded["plenary.curl"] = original_curl
	end)
end)
