local curl = require("plenary.curl")
local pulse = require("maorun.code-stats.pulse")

local defaults = {
	status_prefix = "C:S ",
	api_url = "https://codestats.net/",
	api_key = "",
}
local config = defaults

local error = ""
local function setup(user_config)
	local globalConfig = {}
	if vim.g.codestats_api_key then
		globalConfig.api_key = vim.g.codestats_api_key
	end
	config = vim.tbl_deep_extend("force", defaults, user_config or {}, globalConfig)
	return config
end

local function currentXp()
	if string.len(error) > 0 then
		return config.status_prefix .. "ERR"
	end

	return config.status_prefix .. pulse.getXp(vim.bo.filetype)
end

local function requestToApi(body)
	local url = config.api_url

	return curl.request({
		url = url .. "api/my/pulses/",
		method = "POST",
		headers = {
			["X-API-Token"] = config.api_key,
			["Content-Type"] = "application/json",
			["Accept"] = "application/json",
		},
		body = body,
		on_error = function(data)
			error = "could not send request to code-stats: " .. data.message
		end,
		callback = function()
			error = ""
			pulse.reset()
		end,
	})
end

local function pulseSend()
	if string.len(table.concat(vim.tbl_values(config))) == 0 then
		error = config.status_prefix .. "Not Initialized"
	end

	local url = config.api_url
	if string.len(url) == 0 then
		error = "no API-URL given"
	end
	if string.len(config.api_key) == 0 then
		error = "no api-key given"
	end

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

local group = vim.api.nvim_create_augroup("codestats_track", { clear = true })

vim.api.nvim_create_autocmd({ "InsertCharPre", "TextChanged" }, {
	group = group,
	pattern = "*",
	callback = function()
		require("maorun.code-stats").add(vim.bo.filetype)
	end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
	group = group,
	pattern = "*",
	callback = function()
		require("maorun.code-stats").pulseSend()
	end,
})

vim.api.nvim_create_autocmd({ "BufWrite", "BufLeave" }, {
	group = group,
	pattern = "*",
	callback = function()
		require("maorun.code-stats").pulseSend()
	end,
})

function add(filetype)
	pulse.addXp(filetype, 1)
end

return {
	setup = setup,
	add = add,
	pulseSend = pulseSend,
	currentXp = currentXp,
	getError = function()
		return error
	end,
}
