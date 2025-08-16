-- Statistics calculation module for Code::Stats plugin
-- Provides daily, weekly, and monthly XP and level statistics

local logging = require("maorun.code-stats.logging")
local utils = require("maorun.code-stats.utils")

local statistics = {}

-- Get the path for persisting historical XP data
local function get_history_persistence_path()
	local data_dir = vim.fn.stdpath("data")
	return data_dir .. "/code-stats-history.json"
end

-- Load historical XP data from file
statistics.load_history = function()
	local file_path = get_history_persistence_path()
	local file, err = io.open(file_path, "r")
	if not file then
		if err and not err:match("No such file") then
			logging.warn("Could not open history persistence file: " .. err)
		end
		logging.debug("No history persistence file found, starting fresh")
		return {} -- No historical data
	end

	local success, content = pcall(file.read, file, "*all")
	file:close()

	if not success then
		logging.error("Failed to read history persistence file: " .. content)
		return {}
	end

	if content and content ~= "" then
		local ok, loaded_history = pcall(vim.fn.json_decode, content)
		if not ok then
			logging.error("Failed to parse historical XP data: " .. loaded_history)
			return {}
		end

		if type(loaded_history) == "table" then
			logging.info("Loaded historical XP data with " .. #loaded_history .. " entries")
			return loaded_history
		else
			logging.error("Invalid history file format - expected table, got " .. type(loaded_history))
		end
	end

	return {}
end

-- Save historical XP data to file
statistics.save_history = function(history)
	local file_path = get_history_persistence_path()

	-- If no history, remove the file for consistency
	if not history or #history == 0 then
		local ok, err = pcall(vim.fn.delete, file_path)
		if not ok and err and not err:match("No such file") then
			logging.warn("Failed to delete empty history file: " .. err)
		else
			logging.debug("Removed empty history file")
		end
		return
	end

	local ok, data = pcall(vim.fn.json_encode, history)
	if not ok then
		logging.error("Failed to encode historical data for persistence: " .. data)
		return
	end

	local file, err = io.open(file_path, "w")
	if not file then
		logging.error("Failed to open history persistence file for writing: " .. (err or "unknown error"))
		return
	end

	local success, write_err = pcall(file.write, file, data)
	file:close()

	if not success then
		logging.error("Failed to write historical data to persistence file: " .. write_err)
	else
		logging.info("Historical data persisted to file: " .. file_path)
	end
end

-- Add XP entry with timestamp to history
statistics.add_history_entry = function(language, xp_amount)
	if not language or language == "" or not xp_amount or xp_amount <= 0 then
		return
	end

	local history = statistics.load_history()
	local timestamp = os.time()

	-- Add new entry
	table.insert(history, {
		timestamp = timestamp,
		language = language,
		xp = xp_amount,
		date = os.date("%Y-%m-%d", timestamp),
	})

	-- Keep only last 90 days to prevent excessive growth
	local cutoff = timestamp - (90 * 24 * 60 * 60) -- 90 days ago
	local filtered_history = {}
	for _, entry in ipairs(history) do
		if entry.timestamp >= cutoff then
			table.insert(filtered_history, entry)
		end
	end

	statistics.save_history(filtered_history)
	logging.debug("Added history entry: " .. language .. " +" .. xp_amount .. " XP")
end

-- Use level calculation from utils to avoid duplication
local function calculate_level(xp)
	return utils.calculateLevel(xp)
end

-- Get daily statistics
statistics.get_daily_stats = function(date)
	local history = statistics.load_history()
	local target_date = date or os.date("%Y-%m-%d")

	local daily_xp = {}
	local total_xp = 0

	for _, entry in ipairs(history) do
		if entry.date == target_date then
			daily_xp[entry.language] = (daily_xp[entry.language] or 0) + entry.xp
			total_xp = total_xp + entry.xp
		end
	end

	local languages = {}
	for lang, xp in pairs(daily_xp) do
		table.insert(languages, {
			language = lang,
			xp = xp,
			level = calculate_level(xp),
		})
	end

	-- Sort by XP descending
	table.sort(languages, function(a, b)
		return a.xp > b.xp
	end)

	return {
		date = target_date,
		total_xp = total_xp,
		total_level = calculate_level(total_xp),
		languages = languages,
	}
end

-- Get weekly statistics
statistics.get_weekly_stats = function(date)
	local history = statistics.load_history()
	local target_time = date
			and (type(date) == "string" and os.time({
				year = tonumber(date:sub(1, 4)),
				month = tonumber(date:sub(6, 7)),
				day = tonumber(date:sub(9, 10)),
			}) or date)
		or os.time()

	-- Calculate start of week (Monday)
	local weekday = tonumber(os.date("%w", target_time)) -- 0=Sunday, 1=Monday, etc.
	local days_since_monday = (weekday == 0) and 6 or (weekday - 1)
	local week_start = target_time - (days_since_monday * 24 * 60 * 60)
	local week_end = week_start + (6 * 24 * 60 * 60) -- Add 6 days to get Sunday

	local weekly_xp = {}
	local total_xp = 0

	for _, entry in ipairs(history) do
		if entry.timestamp >= week_start and entry.timestamp <= week_end then
			weekly_xp[entry.language] = (weekly_xp[entry.language] or 0) + entry.xp
			total_xp = total_xp + entry.xp
		end
	end

	local languages = {}
	for lang, xp in pairs(weekly_xp) do
		table.insert(languages, {
			language = lang,
			xp = xp,
			level = calculate_level(xp),
		})
	end

	-- Sort by XP descending
	table.sort(languages, function(a, b)
		return a.xp > b.xp
	end)

	return {
		week_start = os.date("%Y-%m-%d", week_start),
		week_end = os.date("%Y-%m-%d", week_end),
		total_xp = total_xp,
		total_level = calculate_level(total_xp),
		languages = languages,
	}
end

-- Get monthly statistics
statistics.get_monthly_stats = function(year, month)
	local history = statistics.load_history()
	local target_year = year or tonumber(os.date("%Y"))
	local target_month = month or tonumber(os.date("%m"))

	local monthly_xp = {}
	local total_xp = 0

	for _, entry in ipairs(history) do
		local entry_time = entry.timestamp
		local entry_year = tonumber(os.date("%Y", entry_time))
		local entry_month = tonumber(os.date("%m", entry_time))

		if entry_year == target_year and entry_month == target_month then
			monthly_xp[entry.language] = (monthly_xp[entry.language] or 0) + entry.xp
			total_xp = total_xp + entry.xp
		end
	end

	local languages = {}
	for lang, xp in pairs(monthly_xp) do
		table.insert(languages, {
			language = lang,
			xp = xp,
			level = calculate_level(xp),
		})
	end

	-- Sort by XP descending
	table.sort(languages, function(a, b)
		return a.xp > b.xp
	end)

	return {
		year = target_year,
		month = target_month,
		month_name = os.date("%B", os.time({ year = target_year, month = target_month, day = 1 })),
		total_xp = total_xp,
		total_level = calculate_level(total_xp),
		languages = languages,
	}
end

-- Format daily statistics for display
statistics.format_daily_stats = function(stats)
	local result = "Daily Statistics for " .. stats.date .. ":\n"
	result = result .. "Total XP: " .. stats.total_xp .. " (Level " .. stats.total_level .. ")\n"

	if #stats.languages == 0 then
		result = result .. "No coding activity recorded"
	else
		result = result .. "Languages:\n"
		for _, lang_stats in ipairs(stats.languages) do
			result = result
				.. string.format("  %s: %d XP (Level %d)\n", lang_stats.language, lang_stats.xp, lang_stats.level)
		end
		-- Remove trailing newline
		result = result:sub(1, -2)
	end

	return result
end

-- Format weekly statistics for display
statistics.format_weekly_stats = function(stats)
	local result = "Weekly Statistics (" .. stats.week_start .. " to " .. stats.week_end .. "):\n"
	result = result .. "Total XP: " .. stats.total_xp .. " (Level " .. stats.total_level .. ")\n"

	if #stats.languages == 0 then
		result = result .. "No coding activity recorded"
	else
		result = result .. "Languages:\n"
		for _, lang_stats in ipairs(stats.languages) do
			result = result
				.. string.format("  %s: %d XP (Level %d)\n", lang_stats.language, lang_stats.xp, lang_stats.level)
		end
		-- Remove trailing newline
		result = result:sub(1, -2)
	end

	return result
end

-- Format monthly statistics for display
statistics.format_monthly_stats = function(stats)
	local result = "Monthly Statistics for " .. stats.month_name .. " " .. stats.year .. ":\n"
	result = result .. "Total XP: " .. stats.total_xp .. " (Level " .. stats.total_level .. ")\n"

	if #stats.languages == 0 then
		result = result .. "No coding activity recorded"
	else
		result = result .. "Languages:\n"
		for _, lang_stats in ipairs(stats.languages) do
			result = result
				.. string.format("  %s: %d XP (Level %d)\n", lang_stats.language, lang_stats.xp, lang_stats.level)
		end
		-- Remove trailing newline
		result = result:sub(1, -2)
	end

	return result
end

return statistics
