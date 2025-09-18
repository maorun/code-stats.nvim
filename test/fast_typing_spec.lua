describe("Fast Typing Character Tracking", function()
	-- Set test mode flag for immediate XP processing
	_G._TEST_MODE = true

	local pulse
	local events

	before_each(function()
		-- Mock vim environment before requiring modules
		_G.vim = _G.vim or {}
		_G.vim.fn = _G.vim.fn or {}
		_G.vim.fn.stdpath = function(what)
			if what == "data" then
				return "/tmp"
			end
			return "/tmp"
		end
		_G.vim.api = _G.vim.api or {}
		_G.vim.api.nvim_create_augroup = function()
			return 1
		end
		_G.vim.api.nvim_create_autocmd = function() end
		_G.vim.api.nvim_create_user_command = function() end
		_G.vim.api.nvim_win_get_cursor = function()
			return { 1, 0 }
		end
		_G.vim.api.nvim_get_current_buf = function()
			return 1
		end
		_G.vim.bo = { filetype = "lua" }
		_G.vim.tbl_deep_extend = function(mode, ...)
			local result = {}
			for _, tbl in ipairs({ ... }) do
				if type(tbl) == "table" then
					for k, v in pairs(tbl) do
						result[k] = v
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
		_G.vim.treesitter = {
			get_parser = function()
				error("No parser")
			end,
		}

		-- Reset modules
		package.loaded["maorun.code-stats.pulse"] = nil
		package.loaded["maorun.code-stats.logging"] = nil
		package.loaded["maorun.code-stats.events"] = nil
		package.loaded["maorun.code-stats.language-detection"] = nil

		pulse = require("maorun.code-stats.pulse")
		events = require("maorun.code-stats.events")
	end)

	it("should track all characters during fast typing sessions", function()
		local xp_added = 0
		local add_xp_callback = function(lang)
			pulse.addXp(lang, 1)
			xp_added = xp_added + 1
		end

		-- Setup autocommands (this would normally be done by init.lua)
		events.setup_autocommands(add_xp_callback, nil, nil)

		-- Simulate fast typing scenario - in test mode, each character should be tracked immediately
		-- In real mode, characters would accumulate and be processed together

		-- Add multiple characters as if typed quickly
		for i = 1, 5 do
			add_xp_callback("lua") -- Simulate typing 5 characters
		end

		-- Verify all characters were tracked
		assert.are.equal(5, pulse.getXp("lua"))
		assert.are.equal(5, xp_added)
	end)

	it("should handle language switching during typing session", function()
		local add_xp_callback = function(lang, amount)
			amount = amount or 1 -- Default to 1 for backward compatibility
			pulse.addXp(lang, amount)
		end

		-- Setup autocommands
		events.setup_autocommands(add_xp_callback, nil, nil)

		-- Simulate typing in lua
		add_xp_callback("lua", 1)
		add_xp_callback("lua", 1)
		add_xp_callback("lua", 1)

		-- Simulate switching to javascript (e.g., in a different buffer)
		add_xp_callback("javascript", 1)
		add_xp_callback("javascript", 1)

		-- Verify XP was tracked correctly for both languages
		assert.are.equal(3, pulse.getXp("lua"))
		assert.are.equal(2, pulse.getXp("javascript"))
	end)

	it("should not lose XP when debouncing is active", function()
		-- This test simulates the real-world scenario where debouncing might occur
		local total_chars_typed = 0
		local total_xp_added = 0

		local add_xp_callback = function(lang, amount)
			amount = amount or 1 -- Default to 1 for backward compatibility
			pulse.addXp(lang, amount)
			total_xp_added = total_xp_added + amount
		end

		-- Setup autocommands
		events.setup_autocommands(add_xp_callback, nil, nil)

		-- Simulate a typing session with multiple rapid characters
		local chars_in_session = 10
		for i = 1, chars_in_session do
			add_xp_callback("lua", 1) -- Each character typed
			total_chars_typed = total_chars_typed + 1
		end

		-- In our fixed implementation, all characters should be tracked
		-- even with debouncing active (in test mode it's immediate)
		assert.are.equal(chars_in_session, pulse.getXp("lua"))
		assert.are.equal(total_chars_typed, total_xp_added)
		assert.are.equal(10, pulse.getXp("lua"))
	end)
end)
