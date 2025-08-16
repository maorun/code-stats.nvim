local curl = require("plenary.curl")
local pulse = require("maorun.code-stats.pulse")
local cs_config = require("maorun.code-stats.config")
local logging = require("maorun.code-stats.logging")

local error_message = ""
local is_vim_leaving = false

local function requestToApi(body)
	local url = cs_config.config.api_url
	local full_url = url .. "api/my/pulses/"

	logging.debug("Attempting API request to " .. full_url)

	return curl.request({
		url = full_url,
		method = "POST",
		headers = {
			["X-API-Token"] = cs_config.config.api_key,
			["Content-Type"] = "application/json",
			["Accept"] = "application/json",
		},
		body = body,
		on_error = function(data)
			local error_details = data.message or "Unknown network error"
			error_message = "Unable to sync with Code::Stats server: " .. error_details
			logging.log_api_request(full_url, "POST", false, error_details)

			-- If we're leaving vim and there's an error, persist the XP data
			if is_vim_leaving then
				pulse.save()
				logging.warn("XP data persisted due to API error during vim exit")
			end
		end,
		callback = function(response)
			if response.status >= 200 and response.status < 300 then
				error_message = ""
				pulse.reset()
				logging.log_api_request(full_url, "POST", true)
				logging.info("XP data successfully sent to Code::Stats")
			else
				error_message = "Code::Stats server error (HTTP " .. response.status .. ")"
				logging.log_api_request(full_url, "POST", false, "HTTP " .. response.status)
			end
		end,
	})
end

local function pulseSend()
	logging.debug("Starting pulse send operation")

	-- Check if config is initialized by checking essential string fields
	local config_values = {
		cs_config.config.status_prefix,
		cs_config.config.api_url,
		cs_config.config.api_key,
	}
	if string.len(table.concat(config_values)) == 0 then
		error_message = "Code::Stats plugin not properly configured"
		logging.error("Plugin configuration incomplete - missing essential settings")
		return
	end

	local url = cs_config.config.api_url
	if string.len(url) == 0 then
		error_message = "Code::Stats API URL not configured"
		logging.error("Missing API URL configuration")
		return
	end

	if string.len(cs_config.config.api_key) == 0 then
		error_message = "Code::Stats API key not configured"
		logging.error("Missing API key configuration")
		return
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
		local timestamp = os.date("%Y-%m-%dT%X%z")
		local payload = '{ "coded_at": "' .. timestamp .. '", "xps": [ ' .. xps .. " ] }"
		logging.info("Sending XP data: " .. xps)
		requestToApi(payload)
	elseif is_vim_leaving then
		-- If we're leaving vim but have no XP to send, still clean up any persistence file
		pulse.reset()
		logging.info("No XP to send on vim exit, cleaning up persistence")
	else
		logging.debug("No XP data to send")
	end
end

local function pulseSendOnExit()
	logging.info("Performing final pulse send on vim exit")
	is_vim_leaving = true
	pulseSend()
	is_vim_leaving = false
end

local function get_error()
	return error_message
end

local function getProfile(callback)
	logging.debug("Starting profile request operation")

	-- Check if config is initialized by checking essential string fields
	local config_values = {
		cs_config.config.status_prefix,
		cs_config.config.api_url,
		cs_config.config.api_key,
	}
	if string.len(table.concat(config_values)) == 0 then
		local error_msg = "Code::Stats plugin not properly configured"
		logging.error("Plugin configuration incomplete - missing essential settings")
		if callback then
			callback(nil, error_msg)
		end
		return
	end

	local url = cs_config.config.api_url
	if string.len(url) == 0 then
		local error_msg = "Code::Stats API URL not configured"
		logging.error("Missing API URL configuration")
		if callback then
			callback(nil, error_msg)
		end
		return
	end

	if string.len(cs_config.config.api_key) == 0 then
		local error_msg = "Code::Stats API key not configured"
		logging.error("Missing API key configuration")
		if callback then
			callback(nil, error_msg)
		end
		return
	end

	local full_url = url .. "api/my/profile"
	logging.debug("Attempting profile API request to " .. full_url)

	return curl.request({
		url = full_url,
		method = "GET",
		headers = {
			["X-API-Token"] = cs_config.config.api_key,
			["Accept"] = "application/json",
		},
		on_error = function(data)
			local error_details = data.message or "Unknown network error"
			local error_msg = "Unable to retrieve profile from Code::Stats server: " .. error_details
			logging.log_api_request(full_url, "GET", false, error_details)
			if callback then
				callback(nil, error_msg)
			end
		end,
		callback = function(response)
			if response.status >= 200 and response.status < 300 then
				logging.log_api_request(full_url, "GET", true)
				logging.info("Profile data successfully retrieved from Code::Stats")
				if callback then
					callback(response.body, nil)
				end
			else
				local error_msg = "Code::Stats server error (HTTP " .. response.status .. ")"
				logging.log_api_request(full_url, "GET", false, "HTTP " .. response.status)
				if callback then
					callback(nil, error_msg)
				end
			end
		end,
	})
end

return {
	pulseSend = pulseSend,
	pulseSendOnExit = pulseSendOnExit,
	requestToApi = requestToApi,
	get_error = get_error,
	getProfile = getProfile,
}
