describe("Statistics", function()
	local statistics

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

		-- Reset the modules before each test to ensure a clean state
		package.loaded["maorun.code-stats.statistics"] = nil
		package.loaded["maorun.code-stats.logging"] = nil
		statistics = require("maorun.code-stats.statistics")
	end)

	describe("Historical data persistence", function()
		local mock_file_data = nil

		before_each(function()
			mock_file_data = nil

			-- Mock vim.fn.json_encode and json_decode
			_G.vim.fn.json_encode = function(data)
				if type(data) == "table" and #data > 0 then
					local encoded = "["
					for i, entry in ipairs(data) do
						if i > 1 then
							encoded = encoded .. ","
						end
						encoded = encoded
							.. string.format(
								'{"timestamp":%d,"language":"%s","xp":%d,"date":"%s"}',
								entry.timestamp,
								entry.language,
								entry.xp,
								entry.date
							)
					end
					encoded = encoded .. "]"
					return encoded
				end
				return "[]"
			end

			_G.vim.fn.json_decode = function(str)
				if str == "[]" then
					return {}
				end
				-- Simple mock for test data
				if str:match('"language":"lua"') then
					return {
						{
							timestamp = 1609459200, -- 2021-01-01 00:00:00 UTC
							language = "lua",
							xp = 5,
							date = "2021-01-01",
						},
					}
				end
				return {}
			end

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
		end)

		it("should save and load empty history", function()
			local history = statistics.load_history()
			assert.are.same({}, history)
		end)

		it("should save and load historical data", function()
			-- Mock file content
			mock_file_data = '[{"timestamp":1609459200,"language":"lua","xp":5,"date":"2021-01-01"}]'

			local history = statistics.load_history()
			assert.are.equal(1, #history)
			assert.are.equal("lua", history[1].language)
			assert.are.equal(5, history[1].xp)
			assert.are.equal("2021-01-01", history[1].date)
		end)

		it("should add history entry", function()
			-- Mock os.time and os.date
			local original_time = os.time
			local original_date = os.date
			os.time = function()
				return 1609459200
			end
			os.date = function(format, time)
				if format == "%Y-%m-%d" then
					return "2021-01-01"
				end
				return "2021-01-01"
			end

			statistics.add_history_entry("lua", 10)
			assert.is_not_nil(mock_file_data)
			assert.is_true(mock_file_data:match('"language":"lua"') ~= nil)

			-- Restore original functions
			os.time = original_time
			os.date = original_date
		end)
	end)

	describe("Statistics calculations", function()
		local mock_history

		before_each(function()
			-- Mock time functions for consistent testing
			local original_time = os.time
			local original_date = os.date

			-- Mock current time as 2021-01-15 12:00:00 (Friday)
			local mock_current_time = 1610712000

			os.time = function(t)
				if t then
					-- For specific date construction
					return original_time(t)
				end
				return mock_current_time
			end

			os.date = function(format, time)
				local target_time = time or mock_current_time
				if format == "%Y-%m-%d" then
					if target_time == mock_current_time then
						return "2021-01-15"
					end
				elseif format == "%w" then
					if target_time == mock_current_time then
						return "5" -- Friday
					end
				elseif format == "%Y" then
					return "2021"
				elseif format == "%m" then
					return "01"
				elseif format == "%B" then
					return "January"
				end
				return original_date(format, target_time)
			end

			-- Mock historical data
			mock_history = {
				{ timestamp = 1610640000, language = "lua", xp = 10, date = "2021-01-14" }, -- Yesterday
				{ timestamp = 1610712000, language = "lua", xp = 5, date = "2021-01-15" }, -- Today
				{ timestamp = 1610712000, language = "python", xp = 8, date = "2021-01-15" }, -- Today
				{ timestamp = 1610798400, language = "lua", xp = 3, date = "2021-01-16" }, -- Tomorrow (future)
			}

			-- Mock load_history to return our test data
			statistics.load_history = function()
				return mock_history
			end
		end)

		it("should calculate daily statistics correctly", function()
			local daily_stats = statistics.get_daily_stats("2021-01-15")

			assert.are.equal("2021-01-15", daily_stats.date)
			assert.are.equal(13, daily_stats.total_xp) -- 5 + 8
			assert.are.equal(2, daily_stats.total_level) -- Level for 13 XP
			assert.are.equal(2, #daily_stats.languages)

			-- Check languages are sorted by XP descending
			assert.are.equal("python", daily_stats.languages[1].language)
			assert.are.equal(8, daily_stats.languages[1].xp)
			assert.are.equal("lua", daily_stats.languages[2].language)
			assert.are.equal(5, daily_stats.languages[2].xp)
		end)

		it("should format daily statistics correctly", function()
			local daily_stats = statistics.get_daily_stats("2021-01-15")
			local formatted = statistics.format_daily_stats(daily_stats)

			assert.is_true(formatted:match("Daily Statistics for 2021%-01%-15:") ~= nil)
			assert.is_true(formatted:match("Total XP: 13") ~= nil)
			assert.is_true(formatted:match("python: 8 XP") ~= nil)
			assert.is_true(formatted:match("lua: 5 XP") ~= nil)
		end)

		it("should calculate weekly statistics correctly", function()
			-- 2021-01-15 is Friday, so week should be 2021-01-11 to 2021-01-17
			local weekly_stats = statistics.get_weekly_stats()

			assert.are.equal("2021-01-11", weekly_stats.week_start)
			assert.are.equal("2021-01-17", weekly_stats.week_end)
			-- Should include both 2021-01-14 and 2021-01-15 data
			assert.are.equal(23, weekly_stats.total_xp) -- 10 + 5 + 8
		end)

		it("should calculate monthly statistics correctly", function()
			local monthly_stats = statistics.get_monthly_stats(2021, 1)

			assert.are.equal(2021, monthly_stats.year)
			assert.are.equal(1, monthly_stats.month)
			assert.are.equal("January", monthly_stats.month_name)
			-- Should include all January 2021 data
			assert.are.equal(26, monthly_stats.total_xp) -- 10 + 5 + 8 + 3
		end)

		it("should handle empty statistics gracefully", function()
			-- Mock empty history
			statistics.load_history = function()
				return {}
			end

			local daily_stats = statistics.get_daily_stats("2021-01-15")
			assert.are.equal(0, daily_stats.total_xp)
			assert.are.equal(1, daily_stats.total_level) -- Level 1 for 0 XP
			assert.are.equal(0, #daily_stats.languages)

			local formatted = statistics.format_daily_stats(daily_stats)
			assert.is_true(formatted:match("No coding activity recorded") ~= nil)
		end)
	end)

	describe("Level calculations", function()
		it("should calculate level 1 for 0 XP", function()
			local daily_stats = statistics.get_daily_stats("2099-01-01") -- Future date with no data
			assert.are.equal(1, daily_stats.total_level)
		end)

		it("should calculate level 2 for 100 XP", function()
			-- Mock history with 100 XP
			statistics.load_history = function()
				return { { timestamp = os.time(), language = "lua", xp = 100, date = os.date("%Y-%m-%d") } }
			end

			local daily_stats = statistics.get_daily_stats()
			assert.are.equal(2, daily_stats.total_level)
		end)

		it("should calculate level 3 for 400 XP", function()
			-- Mock history with 400 XP
			statistics.load_history = function()
				return { { timestamp = os.time(), language = "lua", xp = 400, date = os.date("%Y-%m-%d") } }
			end

			local daily_stats = statistics.get_daily_stats()
			assert.are.equal(3, daily_stats.total_level)
		end)
	end)
end)
