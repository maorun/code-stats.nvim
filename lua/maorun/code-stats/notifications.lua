local logging = require("maorun.code-stats.logging")

local M = {}

-- Configuration reference (will be set by setup)
local config = nil

-- Setup notifications with config reference
M.setup = function(notification_config)
	config = notification_config
	logging.debug("Notifications module configured")
end

-- Send level-up notification
M.level_up = function(language, new_level)
	if not config or not config.notifications.enabled or not config.notifications.level_up.enabled then
		return
	end

	local message = string.format(config.notifications.level_up.message, language, new_level)

	-- Use vim.notify if available (Neovim 0.5+), fallback to echo
	if vim.notify then
		vim.notify(message, vim.log.levels.INFO, {
			title = "Code::Stats",
			timeout = 3000,
		})
	else
		-- Fallback for older Neovim versions
		vim.api.nvim_echo({ { message, "MoreMsg" } }, true, {})
	end

	logging.info("Level-up notification sent: " .. message)
end

return M
