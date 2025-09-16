local defaults = {
	status_prefix = "C:S ",
	api_url = "https://codestats.net/",
	api_key = "",
	ignored_filetypes = {},
	enhanced_statusline = false, -- Show XP, level, and progress in statusline
	statusline_format = "%s%d (%d%% to L%d)", -- Format: prefix, xp, progress%, next_level
	notifications = {
		enabled = true, -- Enable all notifications
		level_up = {
			enabled = true, -- Enable level-up notifications
			message = "🎉 Level Up! %s reached level %d!", -- Format: language, new_level
		},
	},
	logging = {
		enabled = false,
		level = "INFO", -- ERROR, WARN, INFO, DEBUG
		file_path = nil, -- Will default to vim.fn.stdpath("data") .. "/code-stats.log" if not set
	},
	performance = {
		typing_debounce_ms = 500, -- Debounce time for TextChangedI events (ms)
		xp_batch_delay_ms = 100, -- Batch delay for XP processing (ms)
		cache_timeout_s = 1, -- Language detection cache timeout (seconds)
	},
}
local config = defaults

local logging = require("maorun.code-stats.logging")
local notifications = require("maorun.code-stats.notifications")

local M = {
	config = vim.deepcopy(defaults),
}

function M.setup(user_config)
	local globalConfig = {}
	if vim.g.codestats_api_key then
		globalConfig.api_key = vim.g.codestats_api_key
	end
	config = vim.tbl_deep_extend("force", defaults, user_config or {}, globalConfig)
	M.config = config

	-- Configure logging based on config
	local log_config = {
		enabled = config.logging.enabled,
		file_path = config.logging.file_path,
	}

	-- Convert string level to number
	if type(config.logging.level) == "string" then
		local level_map = {
			ERROR = logging.levels.ERROR,
			WARN = logging.levels.WARN,
			INFO = logging.levels.INFO,
			DEBUG = logging.levels.DEBUG,
		}
		log_config.level = level_map[config.logging.level] or logging.levels.INFO
	else
		log_config.level = config.logging.level
	end

	logging.setup(log_config)
	logging.log_config("Plugin configured with logging " .. (config.logging.enabled and "enabled" or "disabled"))

	-- Setup notifications with the config
	notifications.setup(config)

	return config
end

return M
