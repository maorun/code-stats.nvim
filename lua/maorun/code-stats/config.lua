local defaults = {
	status_prefix = "C:S ",
	api_url = "https://codestats.net/",
	api_key = "",
}
local config = defaults

local function setup(user_config)
	local globalConfig = {}
	if vim.g.codestats_api_key then
		globalConfig.api_key = vim.g.codestats_api_key
	end
	config = vim.tbl_deep_extend("force", defaults, user_config or {}, globalConfig)
	return config
end

return {
    setup = setup,
    config = config,
}
