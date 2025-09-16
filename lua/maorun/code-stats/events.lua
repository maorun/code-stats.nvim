local lang_detection = require("maorun.code-stats.language-detection")
local logging = require("maorun.code-stats.logging")
local cs_config = require("maorun.code-stats.config")

local function setup_autocommands(add_xp_callback, pulse_send_callback, pulse_send_on_exit_callback)
	logging.log_init("Setting up autocommands for XP tracking")
	local group = vim.api.nvim_create_augroup("codestats_track", { clear = true })

	-- Use less frequent events to avoid performance issues with character input
	-- Track XP on significant events rather than every character
	vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
		group = group,
		pattern = "*",
		callback = function()
			if add_xp_callback then
				local detected_lang = lang_detection.detect_language()
				add_xp_callback(detected_lang)
			end
		end,
	})

	-- Additional tracking for continuous typing sessions with configurable debouncing
	local typing_timer = nil
	vim.api.nvim_create_autocmd("TextChangedI", {
		group = group,
		pattern = "*",
		callback = function()
			-- Debounce: only track XP after configured delay of no typing
			if typing_timer then
				vim.fn.timer_stop(typing_timer)
			end
			local debounce_ms = cs_config.config.performance.typing_debounce_ms
			typing_timer = vim.fn.timer_start(debounce_ms, function()
				if add_xp_callback then
					local detected_lang = lang_detection.detect_language()
					add_xp_callback(detected_lang)
				end
				typing_timer = nil
			end)
		end,
	})

	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		pattern = "*",
		callback = function()
			if pulse_send_on_exit_callback then
				pulse_send_on_exit_callback()
			end
		end,
	})

	vim.api.nvim_create_autocmd({ "BufWrite", "BufLeave" }, {
		group = group,
		pattern = "*",
		callback = function()
			if pulse_send_callback then
				pulse_send_callback()
			end
		end,
	})

	logging.log_init("Autocommands configured successfully")
end

return {
	setup_autocommands = setup_autocommands,
}
