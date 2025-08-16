local lang_detection = require("maorun.code-stats.language-detection")
local logging = require("maorun.code-stats.logging")

local function setup_autocommands(add_xp_callback, pulse_send_callback, pulse_send_on_exit_callback)
	logging.log_init("Setting up autocommands for XP tracking")
	local group = vim.api.nvim_create_augroup("codestats_track", { clear = true })

	vim.api.nvim_create_autocmd({ "InsertCharPre", "TextChanged" }, {
		group = group,
		pattern = "*",
		callback = function()
			if add_xp_callback then
				local detected_lang = lang_detection.detect_language()
				add_xp_callback(detected_lang)
			end
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
