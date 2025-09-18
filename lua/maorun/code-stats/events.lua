local lang_detection = require("maorun.code-stats.language-detection")
local logging = require("maorun.code-stats.logging")

-- Lazy load config to avoid circular dependencies
local function get_config()
	local ok, cs_config = pcall(require, "maorun.code-stats.config")
	if ok and cs_config.config.performance then
		return cs_config.config.performance
	end
	-- Default fallback for tests and when config isn't available
	return {
		typing_debounce_ms = 500,
	}
end

local function setup_autocommands(add_xp_callback, pulse_send_callback, pulse_send_on_exit_callback)
	logging.log_init("Setting up autocommands for XP tracking")
	local group = vim.api.nvim_create_augroup("codestats_track", { clear = true })

	-- Track accumulated characters during typing sessions
	local typing_session = {
		accumulated_chars = 0,
		timer = nil,
		current_lang = nil,
	}

	-- Use less frequent events to avoid performance issues with character input
	-- Track XP on significant events rather than every character
	vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
		group = group,
		pattern = "*",
		callback = function()
			-- Process any accumulated characters from typing session
			if typing_session.accumulated_chars > 0 and typing_session.current_lang and add_xp_callback then
				logging.debug(
					string.format(
						"InsertLeave/TextChanged: processing %d accumulated characters for %s",
						typing_session.accumulated_chars,
						typing_session.current_lang
					)
				)
				-- Add all accumulated XP in a single call
				add_xp_callback(typing_session.current_lang, typing_session.accumulated_chars)
				-- Reset session
				typing_session.accumulated_chars = 0
				typing_session.current_lang = nil
			end

			-- Also process current event as usual (single character)
			if add_xp_callback then
				local detected_lang = lang_detection.detect_language()
				add_xp_callback(detected_lang, 1)
			end
		end,
	})

	-- Additional tracking for continuous typing sessions with configurable debouncing
	vim.api.nvim_create_autocmd("TextChangedI", {
		group = group,
		pattern = "*",
		callback = function()
			local detected_lang = lang_detection.detect_language()

			-- Accumulate character count for this typing session
			typing_session.accumulated_chars = typing_session.accumulated_chars + 1
			typing_session.current_lang = detected_lang

			-- Stop existing timer if it exists
			if typing_session.timer and vim.fn and vim.fn.timer_stop then
				vim.fn.timer_stop(typing_session.timer)
			end

			local perf_config = get_config()
			local debounce_ms = perf_config.typing_debounce_ms

			-- Check for test environment - use _G._TEST_MODE or absence of timer functions
			local is_test_env = _G._TEST_MODE or (vim.fn and not vim.fn.timer_start)

			if not is_test_env and vim.fn and vim.fn.timer_start then
				typing_session.timer = vim.fn.timer_start(debounce_ms, function()
					-- Process accumulated characters when typing pauses
					if typing_session.accumulated_chars > 0 and typing_session.current_lang and add_xp_callback then
						logging.debug(
							string.format(
								"Debounce timer: processing %d accumulated characters for %s",
								typing_session.accumulated_chars,
								typing_session.current_lang
							)
						)
						-- Add all accumulated XP in a single call
						add_xp_callback(typing_session.current_lang, typing_session.accumulated_chars)
						-- Reset session
						typing_session.accumulated_chars = 0
						typing_session.current_lang = nil
					end
					typing_session.timer = nil
				end)
			else
				-- Immediate processing for test environment
				if add_xp_callback then
					add_xp_callback(detected_lang, 1)
				end
				-- In test mode, don't accumulate - process immediately
				if is_test_env then
					typing_session.accumulated_chars = 0
					typing_session.current_lang = nil
				end
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
