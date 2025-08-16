local pulse = require("maorun.code-stats.pulse")
local cs_config = require("maorun.code-stats.config")
local api = require("maorun.code-stats.api")
local events = require("maorun.code-stats.events")
local lang_detection = require("maorun.code-stats.language-detection")

-- Load any persisted XP data from previous sessions
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

local M = {}

function M.add(filetype)
	-- Check if filetype is in ignored list
	for _, ignored_type in ipairs(cs_config.config.ignored_filetypes) do
		if filetype == ignored_type then
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

-- Setup autocommands by passing the local add function, api.pulseSend, and api.pulseSendOnExit
events.setup_autocommands(M.add, M.pulseSend, api.pulseSendOnExit)

return M
