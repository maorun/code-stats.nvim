local pulse = require("maorun.code-stats.pulse")
local cs_config = require("maorun.code-stats.config")
local api = require("maorun.code-stats.api")
local events = require("maorun.code-stats.events")
local lang_detection = require("maorun.code-stats.language-detection")
local logging = require("maorun.code-stats.logging")

-- Load any persisted XP data from previous sessions
logging.log_init("Loading persisted XP data")
pulse.load()

-- The local 'error' variable has been removed. Errors are now primarily managed in api.lua.

local function currentXp()
	-- currentXp now relies on M.getError() which gets its value from api.get_error()
	if string.len(api.get_error()) > 0 then
		return cs_config.config.status_prefix .. "ERR"
	end

	local detected_lang = lang_detection.detect_language()
	return cs_config.config.status_prefix .. pulse.getXp(detected_lang)
end

-- Get formatted XP information for the current language
local function getCurrentLanguageXP()
	if string.len(api.get_error()) > 0 then
		return "Error: " .. api.get_error()
	end

	local detected_lang = lang_detection.detect_language()
	local xp = pulse.getXp(detected_lang)
	return string.format("Language: %s, XP: %d", detected_lang or "unknown", xp)
end

-- Get formatted XP information for all tracked languages
local function getAllLanguagesXP()
	if string.len(api.get_error()) > 0 then
		return "Error: " .. api.get_error()
	end

	local result = "Tracked languages and XP:\n"
	local languages = {}

	-- Collect all languages with XP > 0
	for lang, xp in pairs(pulse.xps) do
		if xp > 0 then
			table.insert(languages, { lang = lang, xp = xp })
		end
	end

	-- Sort by XP descending
	table.sort(languages, function(a, b)
		return a.xp > b.xp
	end)

	if #languages == 0 then
		result = result .. "  No XP tracked yet"
	else
		for _, entry in ipairs(languages) do
			result = result .. string.format("  %s: %d XP\n", entry.lang, entry.xp)
		end
		-- Remove trailing newline
		result = result:sub(1, -2)
	end

	return result
end

-- Get formatted XP information for a specific language
local function getLanguageXP(language)
	if string.len(api.get_error()) > 0 then
		return "Error: " .. api.get_error()
	end

	if not language or language == "" then
		return "Error: No language specified"
	end

	local xp = pulse.getXp(language)
	return string.format("Language: %s, XP: %d", language, xp)
end

local M = {}

function M.add(filetype)
	-- Check if filetype is in ignored list
	for _, ignored_type in ipairs(cs_config.config.ignored_filetypes) do
		if filetype == ignored_type then
			logging.debug("Skipping XP for ignored filetype: " .. filetype)
			return -- Don't add XP for ignored filetypes
		end
	end
	pulse.addXp(filetype, 1)
end

M.setup = cs_config.setup
M.pulseSend = api.pulseSend
M.currentXp = currentXp
M.getError = function()
	return api.get_error()
end

-- Public functions for user commands
M.getCurrentLanguageXP = getCurrentLanguageXP
M.getAllLanguagesXP = getAllLanguagesXP
M.getLanguageXP = getLanguageXP

-- Setup autocommands by passing the local add function, api.pulseSend, and api.pulseSendOnExit
events.setup_autocommands(M.add, M.pulseSend, api.pulseSendOnExit)

-- Create user commands
vim.api.nvim_create_user_command("CodeStatsXP", function()
	local info = getCurrentLanguageXP()
	local error_msg = api.get_error()

	if string.len(error_msg) > 0 then
		vim.notify("Code::Stats Error: " .. error_msg, vim.log.levels.ERROR, { title = "Code::Stats" })
		logging.error("User command CodeStatsXP failed: " .. error_msg)
	else
		vim.notify(info, vim.log.levels.INFO, { title = "Code::Stats" })
		logging.debug("User command CodeStatsXP executed successfully")
	end
end, { desc = "Show XP for current language" })

vim.api.nvim_create_user_command("CodeStatsAll", function()
	local info = getAllLanguagesXP()
	local error_msg = api.get_error()

	if string.len(error_msg) > 0 then
		vim.notify("Code::Stats Error: " .. error_msg, vim.log.levels.ERROR, { title = "Code::Stats" })
		logging.error("User command CodeStatsAll failed: " .. error_msg)
	else
		vim.notify(info, vim.log.levels.INFO, { title = "Code::Stats" })
		logging.debug("User command CodeStatsAll executed successfully")
	end
end, { desc = "Show XP for all tracked languages" })

vim.api.nvim_create_user_command("CodeStatsLang", function(opts)
	local info = getLanguageXP(opts.args)
	local error_msg = api.get_error()

	if string.len(error_msg) > 0 then
		vim.notify("Code::Stats Error: " .. error_msg, vim.log.levels.ERROR, { title = "Code::Stats" })
		logging.error("User command CodeStatsLang failed: " .. error_msg)
	else
		vim.notify(info, vim.log.levels.INFO, { title = "Code::Stats" })
		logging.debug("User command CodeStatsLang executed for language: " .. (opts.args or "unknown"))
	end
end, {
	nargs = 1,
	desc = "Show XP for specific language",
	complete = function()
		-- Return list of tracked languages for completion
		local languages = {}
		for lang, xp in pairs(pulse.xps) do
			if xp > 0 then
				table.insert(languages, lang)
			end
		end
		table.sort(languages)
		return languages
	end,
})

-- Add user command for managing logging
vim.api.nvim_create_user_command("CodeStatsLog", function(opts)
	local action = opts.args or ""

	if action == "clear" then
		logging.clear_log()
		vim.notify("Code::Stats log file cleared", vim.log.levels.INFO, { title = "Code::Stats" })
	elseif action == "path" then
		local log_path = logging.get_log_file()
		if log_path and logging.is_enabled() then
			vim.notify("Log file: " .. log_path, vim.log.levels.INFO, { title = "Code::Stats" })
		else
			vim.notify("Logging is disabled", vim.log.levels.WARN, { title = "Code::Stats" })
		end
	elseif action == "status" then
		local status = logging.is_enabled() and "enabled" or "disabled"
		local log_path = logging.get_log_file() or "not set"
		vim.notify(
			"Logging is " .. status .. "\nLog file: " .. log_path,
			vim.log.levels.INFO,
			{ title = "Code::Stats" }
		)
	else
		vim.notify("Usage: :CodeStatsLog [clear|path|status]", vim.log.levels.INFO, { title = "Code::Stats" })
	end
end, {
	nargs = "?",
	desc = "Manage Code::Stats logging (clear|path|status)",
	complete = function()
		return { "clear", "path", "status" }
	end,
})

-- Add user command for manual XP synchronization
vim.api.nvim_create_user_command("CodeStatsXpSend", function()
	local error_msg = api.get_error()

	-- Clear any previous error before sending
	api.pulseSend()

	-- Check for errors after sending
	local new_error_msg = api.get_error()

	if string.len(new_error_msg) > 0 then
		vim.notify("Code::Stats Error: " .. new_error_msg, vim.log.levels.ERROR, { title = "Code::Stats" })
		logging.error("User command CodeStatsXpSend failed: " .. new_error_msg)
	else
		vim.notify("XP data successfully sent to Code::Stats", vim.log.levels.INFO, { title = "Code::Stats" })
		logging.debug("User command CodeStatsXpSend executed successfully")
	end
end, { desc = "Send all pending XP to Code::Stats immediately" })

logging.log_init("User commands created successfully")
logging.log_init("Code::Stats plugin initialization complete")

return M
