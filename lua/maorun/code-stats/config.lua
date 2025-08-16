local defaults = {
	status_prefix = "C:S ",
	api_url = "https://codestats.net/",
	api_key = "",
	ignored_filetypes = {},
	logging = {
		enabled = false,
		level = "INFO", -- ERROR, WARN, INFO, DEBUG
		file_path = nil, -- Will default to vim.fn.stdpath("data") .. "/code-stats.log" if not set
	},
}
local config = defaults

local logging = require("maorun.code-stats.logging")

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

	return config
end

return M
