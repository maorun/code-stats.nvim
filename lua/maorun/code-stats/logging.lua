-- Centralized logging system for Code::Stats plugin
-- Supports optional file logging with configurable levels

local M = {}

-- Log levels
M.levels = {
	ERROR = 1,
	WARN = 2,
	INFO = 3,
	DEBUG = 4,
}

-- Level names for output
local level_names = {
	[M.levels.ERROR] = "ERROR",
	[M.levels.WARN] = "WARN",
	[M.levels.INFO] = "INFO",
	[M.levels.DEBUG] = "DEBUG",
}

-- Default configuration
local config = {
	enabled = false,
	level = M.levels.INFO,
	file_path = nil,
}

-- Configure logging
function M.setup(user_config)
	if user_config then
		config = vim.tbl_deep_extend("force", config, user_config)
	end

	-- Set default log file path if logging is enabled but no path specified
	if config.enabled and not config.file_path then
		local data_dir = vim.fn.stdpath("data")
		config.file_path = data_dir .. "/code-stats.log"
	end
end

-- Get current timestamp for log entries
local function get_timestamp()
	return os.date("%Y-%m-%d %H:%M:%S")
end

-- Write log entry to file
local function write_to_file(level, message)
	if not config.enabled or not config.file_path then
		return
	end

	if level > config.level then
		return
	end

	local timestamp = get_timestamp()
	local level_name = level_names[level] or "UNKNOWN"
	local log_entry = string.format("[%s] [%s] %s\n", timestamp, level_name, message)

	-- Try to write to log file
	local file = io.open(config.file_path, "a")
	if file then
		file:write(log_entry)
		file:close()
	end
end

-- Log an error message
function M.error(message)
	write_to_file(M.levels.ERROR, message)
end

-- Log a warning message
function M.warn(message)
	write_to_file(M.levels.WARN, message)
end

-- Log an info message
function M.info(message)
	write_to_file(M.levels.INFO, message)
end

-- Log a debug message
function M.debug(message)
	write_to_file(M.levels.DEBUG, message)
end

-- Log API requests
function M.log_api_request(url, method, success, error_msg)
	local status = success and "SUCCESS" or "FAILED"
	local msg = string.format("API %s %s - %s", method, url, status)
	if error_msg then
		msg = msg .. " - " .. error_msg
	end

	if success then
		M.info(msg)
	else
		M.error(msg)
	end
end

-- Log XP operations
function M.log_xp_operation(operation, language, amount, total)
	local msg = string.format("XP %s: %s +%d (total: %d)", operation, language, amount or 0, total or 0)
	M.info(msg)
end

-- Log configuration operations
function M.log_config(message)
	M.info("CONFIG: " .. message)
end

-- Log plugin initialization
function M.log_init(message)
	M.info("INIT: " .. message)
end

-- Get current log file path
function M.get_log_file()
	return config.file_path
end

-- Check if logging is enabled
function M.is_enabled()
	return config.enabled
end

-- Clear log file
function M.clear_log()
	if config.enabled and config.file_path then
		local file = io.open(config.file_path, "w")
		if file then
			file:close()
			M.info("Log file cleared")
		end
	end
end

return M
