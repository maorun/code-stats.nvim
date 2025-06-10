local curl = require("plenary.curl")
local pulse = require("maorun.code-stats.pulse")
local cs_config = require("maorun.code-stats.config")

local error_message = ""

local function requestToApi(body)
	local url = cs_config.config.api_url

	return curl.request({
		url = url .. "api/my/pulses/",
		method = "POST",
		headers = {
			["X-API-Token"] = cs_config.config.api_key,
			["Content-Type"] = "application/json",
			["Accept"] = "application/json",
		},
		body = body,
		on_error = function(data)
			error_message = "could not send request to code-stats: " .. data.message
		end,
		callback = function()
			error_message = ""
			pulse.reset()
		end,
	})
end

local function pulseSend()
	if string.len(table.concat(vim.tbl_values(cs_config.config))) == 0 then
		error_message = cs_config.config.status_prefix .. "Not Initialized"
		-- Early return if not initialized, to prevent further checks if config is empty
		if string.len(error_message) > 0 then
			return
		end
	end

	local url = cs_config.config.api_url
	if string.len(url) == 0 then
		error_message = "no API-URL given"
		if string.len(error_message) > 0 then
			return
		end
	end
	if string.len(cs_config.config.api_key) == 0 then
		error_message = "no api-key given"
		if string.len(error_message) > 0 then
			return
		end
	end

	-- If there was an error message set by previous checks, clear it if we proceed
	error_message = ""

	local languages = vim.fn.map(pulse.xps, function(language, xp)
		if xp > 0 then
			return '{"language": "' .. language .. '", "xp": ' .. xp .. "}"
		else
			return ""
		end
	end)

	local xps = table.concat(vim.tbl_values(languages), ",")

	if string.len(xps) > 0 then
		requestToApi('{ "coded_at": "' .. os.date("%Y-%m-%dT%X%z") .. '", "xps": [ ' .. xps .. " ] }")
	end
end

local function get_error()
	return error_message
end

return {
	pulseSend = pulseSend,
	requestToApi = requestToApi,
	get_error = get_error,
}
