local M = {}

-- Language patterns for embedded content detection
local language_patterns = {
	javascript = {
		-- Script tags with type or no type (defaults to javascript)
		{ start_pattern = "<script[^>]*>", end_pattern = "</script>", lang = "javascript" },
		{
			start_pattern = "<script[^>]*type%s*=%s*['\"]text/javascript['\"][^>]*>",
			end_pattern = "</script>",
			lang = "javascript",
		},
		{
			start_pattern = "<script[^>]*type%s*=%s*['\"]application/javascript['\"][^>]*>",
			end_pattern = "</script>",
			lang = "javascript",
		},
	},
	css = {
		-- Style tags
		{ start_pattern = "<style[^>]*>", end_pattern = "</style>", lang = "css" },
		{ start_pattern = "<style[^>]*type%s*=%s*['\"]text/css['\"][^>]*>", end_pattern = "</style>", lang = "css" },
	},
}

-- Get the current cursor position
local function get_cursor_position()
	local cursor = vim.api.nvim_win_get_cursor(0)
	return cursor[1], cursor[2] -- line (1-indexed), column (0-indexed)
end

-- Get buffer content around cursor position
local function get_buffer_content()
	return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

-- Convert line/column to absolute character position
local function get_absolute_position(lines, line, col)
	local pos = 0
	for i = 1, line - 1 do
		if lines[i] then
			pos = pos + #lines[i] + 1 -- +1 for newline
		end
	end
	return pos + col
end

-- Check if cursor is within any embedded language block
local function detect_embedded_language(filetype)
	-- Only check for embedded languages in HTML files
	if filetype ~= "html" then
		return filetype
	end

	local line, col = get_cursor_position()
	local lines = get_buffer_content()
	local content = table.concat(lines, "\n")
	local cursor_pos = get_absolute_position(lines, line, col)

	-- Check each language pattern
	for lang_name, patterns in pairs(language_patterns) do
		for _, pattern in ipairs(patterns) do
			local start_pos = 1
			while true do
				local start_match_begin, start_match_end = content:find(pattern.start_pattern, start_pos)
				if not start_match_begin then
					break
				end

				local end_match_begin, end_match_end = content:find(pattern.end_pattern, start_match_end + 1)
				if not end_match_begin then
					-- No closing tag found, assume it extends to end of file
					end_match_end = #content
				end

				-- Check if cursor is within this block
				if cursor_pos >= start_match_end and cursor_pos <= end_match_begin then
					return pattern.lang
				end

				start_pos = end_match_end + 1
			end
		end
	end

	-- No embedded language detected, return original filetype
	return filetype
end

-- Main function to detect the current language at cursor position
function M.detect_language()
	local base_filetype = vim.bo.filetype
	return detect_embedded_language(base_filetype)
end

-- Function to get supported embedded languages for a given filetype
function M.get_supported_languages(filetype)
	if filetype == "html" then
		return { "html", "css", "javascript" }
	end
	return { filetype }
end

return M
