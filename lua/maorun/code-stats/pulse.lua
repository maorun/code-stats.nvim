local logging = require("maorun.code-stats.logging")
local notifications = require("maorun.code-stats.notifications")

local pulse = {
	xps = {},
}

-- Get the path for persisting XP data
local function get_persistence_path()
	local data_dir = vim.fn.stdpath("data")
	return data_dir .. "/code-stats-xp.json"
end

-- Save XP data to file (only if there are XP values > 0)
pulse.save = function()
	local has_xp = false
	for _, xp in pairs(pulse.xps) do
		if xp > 0 then
			has_xp = true
			break
		end
	end

	if not has_xp then
		-- Remove persistence file if no XP to save
		local file_path = get_persistence_path()
		local ok, err = pcall(vim.fn.delete, file_path)
		if not ok then
			logging.warn("Failed to delete empty persistence file: " .. err)
		else
			logging.debug("Removed empty persistence file")
		end
		return
	end

	local file_path = get_persistence_path()
	local ok, data = pcall(vim.fn.json_encode, pulse.xps)
	if not ok then
		logging.error("Failed to encode XP data for persistence: " .. data)
		return
	end

	local file, err = io.open(file_path, "w")
	if not file then
		logging.error("Failed to open persistence file for writing: " .. (err or "unknown error"))
		return
	end

	local success, write_err = pcall(file.write, file, data)
	file:close()

	if not success then
		logging.error("Failed to write XP data to persistence file: " .. write_err)
	else
		logging.info("XP data persisted to file: " .. file_path)
	end
end

-- Load XP data from file and merge with current XP
pulse.load = function()
	local file_path = get_persistence_path()
	local file, err = io.open(file_path, "r")
	if not file then
		if err and not err:match("No such file") then
			logging.warn("Could not open persistence file: " .. err)
		end
		logging.debug("No persistence file found, starting fresh")
		return -- No persisted data
	end

	local success, content = pcall(file.read, file, "*all")
	file:close()

	if not success then
		logging.error("Failed to read persistence file: " .. content)
		return
	end

	if content and content ~= "" then
		local ok, loaded_xps = pcall(vim.fn.json_decode, content)
		if not ok then
			logging.error("Failed to parse persisted XP data: " .. loaded_xps)
			-- Try to remove corrupted file
			local delete_ok, delete_err = pcall(vim.fn.delete, file_path)
			if not delete_ok then
				logging.warn("Failed to remove corrupted persistence file: " .. delete_err)
			end
			return
		end

		if type(loaded_xps) == "table" then
			-- Merge loaded XP with current XP
			local merged_count = 0
			for lang, xp in pairs(loaded_xps) do
				if type(xp) == "number" and xp > 0 then
					local old_xp = pulse.getXp(lang)
					pulse.xps[lang] = old_xp + xp
					merged_count = merged_count + 1
					logging.debug("Merged " .. xp .. " XP for " .. lang .. " (total: " .. pulse.xps[lang] .. ")")
				end
			end
			logging.info("Loaded and merged " .. merged_count .. " languages from persistence file")

			-- Remove the persistence file after loading
			local delete_ok, delete_err = pcall(vim.fn.delete, file_path)
			if not delete_ok then
				logging.warn("Failed to remove persistence file after loading: " .. delete_err)
			end
		else
			logging.error("Invalid persistence file format - expected table, got " .. type(loaded_xps))
		end
	end
end

pulse.addXp = function(lang, amount)
	if not lang or lang == "" then
		logging.warn("Attempted to add XP to empty language")
		return
	end

	if not amount or amount <= 0 then
		logging.warn("Attempted to add invalid XP amount: " .. tostring(amount))
		return
	end

	local old_xp = pulse.getXp(lang)
	local old_level = pulse.calculateLevel(old_xp)

	pulse.xps[lang] = old_xp + amount
	local new_level = pulse.calculateLevel(pulse.xps[lang])

	logging.log_xp_operation("ADD", lang, amount, pulse.xps[lang])

	-- Check for level-up and send notification
	if new_level > old_level then
		notifications.level_up(lang, new_level)
	end
end

pulse.getXp = function(lang)
	if pulse.xps[lang] then
		return pulse.xps[lang]
	end
	return 0
end

-- Calculate level from XP using standard gaming formula
-- Level = floor(sqrt(XP / 100)) + 1
pulse.calculateLevel = function(xp)
	if not xp or xp <= 0 then
		return 1
	end
	return math.floor(math.sqrt(xp / 100)) + 1
end

-- Calculate XP required for a specific level
pulse.calculateXpForLevel = function(level)
	if not level or level <= 1 then
		return 0
	end
	return (level - 1) * (level - 1) * 100
end

-- Calculate progress to next level as a percentage (0-100)
pulse.calculateProgressToNextLevel = function(xp)
	if not xp or xp <= 0 then
		return 0
	end

	local current_level = pulse.calculateLevel(xp)
	local current_level_xp = pulse.calculateXpForLevel(current_level)
	local next_level_xp = pulse.calculateXpForLevel(current_level + 1)

	-- If we're at the maximum reasonable level, return 100%
	if current_level >= 100 then
		return 100
	end

	local xp_in_current_level = xp - current_level_xp
	local xp_needed_for_next = next_level_xp - current_level_xp

	return math.floor((xp_in_current_level / xp_needed_for_next) * 100)
end

-- Get level for a specific language
pulse.getLevel = function(lang)
	local xp = pulse.getXp(lang)
	return pulse.calculateLevel(xp)
end

-- Get progress to next level for a specific language
pulse.getProgressToNextLevel = function(lang)
	local xp = pulse.getXp(lang)
	return pulse.calculateProgressToNextLevel(xp)
end

pulse.reset = function()
	local lang_count = 0
	for _ in pairs(pulse.xps) do
		lang_count = lang_count + 1
	end

	pulse.xps = {}
	logging.info("Reset XP data (" .. lang_count .. " languages cleared)")

	-- Also remove persistence file when resetting
	local file_path = get_persistence_path()
	local ok, err = pcall(vim.fn.delete, file_path)
	if not ok then
		logging.warn("Failed to delete persistence file during reset: " .. err)
	end
end

return pulse
