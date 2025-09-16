describe("Pulse", function()
	local pulse

	before_each(function()
		-- Set test mode flag for immediate XP processing
		_G._TEST_MODE = true

		-- Mock vim environment before requiring modules
		_G.vim = _G.vim or {}
		_G.vim.fn = _G.vim.fn or {}
		_G.vim.fn.stdpath = function(what)
			if what == "data" then
				return "/tmp"
			end
			return "/tmp"
		end

		-- Reset the pulse module before each test to ensure a clean state
		-- This is important because Lua modules often retain state.
		package.loaded["maorun.code-stats.pulse"] = nil
		package.loaded["maorun.code-stats.logging"] = nil
		pulse = require("maorun.code-stats.pulse")
	end)

	it("should add XP to a language", function()
		pulse.addXp("lua", 10)
		assert.are.equal(10, pulse.getXp("lua"))
	end)

	it("should return 0 XP for a language not yet added", function()
		assert.are.equal(0, pulse.getXp("python"))
	end)

	it("should add XP to multiple languages", function()
		pulse.addXp("lua", 10)
		pulse.addXp("python", 20)
		assert.are.equal(10, pulse.getXp("lua"))
		assert.are.equal(20, pulse.getXp("python"))
	end)

	it("should correctly add XP multiple times to the same language", function()
		pulse.addXp("lua", 10)
		pulse.addXp("lua", 5)
		assert.are.equal(15, pulse.getXp("lua"))
	end)

	it("should reset all XP", function()
		pulse.addXp("lua", 10)
		pulse.addXp("python", 20)
		pulse.reset()
		assert.are.equal(0, pulse.getXp("lua"))
		assert.are.equal(0, pulse.getXp("python"))
	end)

	it("should handle adding zero XP", function()
		pulse.addXp("go", 0)
		assert.are.equal(0, pulse.getXp("go"))
	end)

	it("should reject negative XP amounts", function()
		-- Negative XP should be rejected as invalid
		pulse.addXp("ruby", -5)
		assert.are.equal(0, pulse.getXp("ruby"))
		pulse.addXp("ruby", 10)
		assert.are.equal(10, pulse.getXp("ruby"))
	end)

	it("should save and load XP data (basic persistence)", function()
		-- Mock minimal vim functions for persistence test
		local mock_file_data = nil
		_G.vim = _G.vim or {}
		_G.vim.fn = _G.vim.fn or {}
		local original_stdpath = _G.vim.fn.stdpath
		local original_json_encode = _G.vim.fn.json_encode
		local original_json_decode = _G.vim.fn.json_decode
		local original_delete = _G.vim.fn.delete

		_G.vim.fn.stdpath = function()
			return "/tmp/test"
		end
		_G.vim.fn.json_encode = function(data)
			return '{"lua":' .. (data.lua or 0) .. "}"
		end
		_G.vim.fn.json_decode = function(str)
			if str == '{"lua":10}' then
				return { lua = 10 }
			end
			return {}
		end
		_G.vim.fn.delete = function() end

		-- Mock io.open
		local original_io_open = io.open
		io.open = function(path, mode)
			if mode == "w" then
				return {
					write = function(_, data)
						mock_file_data = data
						return true
					end,
					close = function() end,
				}
			elseif mode == "r" and mock_file_data then
				return {
					read = function(_, format)
						if format == "*all" then
							return mock_file_data
						end
						return mock_file_data
					end,
					close = function() end,
				}
			end
			return nil
		end

		-- Test save
		pulse.addXp("lua", 10)
		pulse.save()
		assert.is_not_nil(mock_file_data)

		-- Test load
		pulse.reset()
		mock_file_data = '{"lua":10}'
		pulse.load()
		assert.are.equal(10, pulse.getXp("lua"))

		-- Restore original functions
		io.open = original_io_open
		_G.vim.fn.stdpath = original_stdpath
		_G.vim.fn.json_encode = original_json_encode
		_G.vim.fn.json_decode = original_json_decode
		_G.vim.fn.delete = original_delete
	end)

	-- Test level calculation functions
	describe("Level calculations", function()
		it("should calculate level 1 for 0 XP", function()
			assert.are.equal(1, pulse.calculateLevel(0))
		end)

		it("should calculate level 1 for 99 XP", function()
			assert.are.equal(1, pulse.calculateLevel(99))
		end)

		it("should calculate level 2 for 100 XP", function()
			assert.are.equal(2, pulse.calculateLevel(100))
		end)

		it("should calculate level 3 for 400 XP", function()
			assert.are.equal(3, pulse.calculateLevel(400))
		end)

		it("should calculate level 6 for 2500 XP", function()
			assert.are.equal(6, pulse.calculateLevel(2500))
		end)

		it("should calculate XP required for levels correctly", function()
			assert.are.equal(0, pulse.calculateXpForLevel(1))
			assert.are.equal(100, pulse.calculateXpForLevel(2))
			assert.are.equal(400, pulse.calculateXpForLevel(3))
			assert.are.equal(2500, pulse.calculateXpForLevel(6))
		end)

		it("should calculate progress to next level correctly", function()
			-- 150 XP = Level 2 (100 XP) + 50 XP progress
			-- Next level (3) requires 400 XP, so 300 XP needed from level 2
			-- Progress: 50/300 = 16.66% -> 16% (floored)
			assert.are.equal(16, pulse.calculateProgressToNextLevel(150))
		end)

		it("should return 0% progress for 0 XP", function()
			assert.are.equal(0, pulse.calculateProgressToNextLevel(0))
		end)

		it("should return 100% progress for very high levels", function()
			-- Level 100+ should return 100% progress
			local very_high_xp = 100 * 100 * 100 -- Level 101
			assert.are.equal(100, pulse.calculateProgressToNextLevel(very_high_xp))
		end)
	end)

	-- Test language-specific level functions
	describe("Language-specific level functions", function()
		it("should return level 1 for language with no XP", function()
			assert.are.equal(1, pulse.getLevel("python"))
		end)

		it("should return correct level for language with XP", function()
			pulse.addXp("lua", 150)
			assert.are.equal(2, pulse.getLevel("lua"))
		end)

		it("should return correct progress for language with XP", function()
			pulse.addXp("javascript", 150)
			assert.are.equal(16, pulse.getProgressToNextLevel("javascript"))
		end)
	end)

	-- Test level-up notifications
	describe("Level-up notifications", function()
		local notifications_called = {}

		before_each(function()
			notifications_called = {}
			-- Mock the notifications module
			package.loaded["maorun.code-stats.notifications"] = {
				level_up = function(lang, level)
					table.insert(notifications_called, { lang = lang, level = level })
				end,
			}
			-- Reload pulse to use the mocked notifications
			package.loaded["maorun.code-stats.pulse"] = nil
			pulse = require("maorun.code-stats.pulse")
		end)

		it("should trigger notification when leveling up from 1 to 2", function()
			-- Level 1: 0-99 XP, Level 2: 100+ XP
			pulse.addXp("lua", 100)
			assert.are.equal(1, #notifications_called)
			assert.are.equal("lua", notifications_called[1].lang)
			assert.are.equal(2, notifications_called[1].level)
		end)

		it("should trigger notification when leveling up from 2 to 3", function()
			-- Level 2: 100-399 XP, Level 3: 400+ XP
			pulse.addXp("python", 400)
			assert.are.equal(1, #notifications_called)
			assert.are.equal("python", notifications_called[1].lang)
			assert.are.equal(3, notifications_called[1].level)
		end)

		it("should not trigger notification when not leveling up", function()
			pulse.addXp("javascript", 50) -- Still level 1
			assert.are.equal(0, #notifications_called)
		end)

		it("should trigger notification only once per level-up", function()
			pulse.addXp("go", 50) -- Level 1, no notification
			assert.are.equal(0, #notifications_called)

			pulse.addXp("go", 50) -- Level 2, should trigger notification
			assert.are.equal(1, #notifications_called)
			assert.are.equal(2, notifications_called[1].level)

			pulse.addXp("go", 50) -- Still level 2, no additional notification
			assert.are.equal(1, #notifications_called)
		end)

		it("should handle multiple languages independently", function()
			pulse.addXp("rust", 100) -- Level 2
			pulse.addXp("typescript", 400) -- Level 3

			assert.are.equal(2, #notifications_called)
			-- Check first notification
			assert.are.equal("rust", notifications_called[1].lang)
			assert.are.equal(2, notifications_called[1].level)
			-- Check second notification
			assert.are.equal("typescript", notifications_called[2].lang)
			assert.are.equal(3, notifications_called[2].level)
		end)
	end)
end)
