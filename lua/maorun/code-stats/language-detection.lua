local M = {}

-- Cache to avoid expensive TreeSitter calls
local language_cache = {
	buffer = -1,
	filetype = "",
	last_line = -1,
	last_col = -1,
	language = "",
	timestamp = 0,
}

-- Get cached configuration to avoid circular dependency
local function get_cache_timeout()
	local ok, cs_config = pcall(require, "maorun.code-stats.config")
	if ok and cs_config.config.performance then
		return cs_config.config.performance.cache_timeout_s
	end
	return 1 -- Default fallback
end

-- Get the current cursor position
local function get_cursor_position()
	local cursor = vim.api.nvim_win_get_cursor(0)
	return cursor[1] - 1, cursor[2] -- Convert to 0-indexed for treesitter
end

-- Attempt to detect language using treesitter language injection
local function detect_language_at_cursor()
	local base_filetype = vim.bo.filetype

	-- Try to get any treesitter parser for the buffer
	local has_parser, parser = pcall(vim.treesitter.get_parser, 0)
	if not has_parser or not parser then
		-- Fallback to original filetype if no treesitter parser
		return base_filetype
	end

	local line, col = get_cursor_position()

	-- Try to get the language tree at the cursor position
	-- This will automatically handle language injection (e.g., CSS in HTML, JS in HTML, etc.)
	local lang_tree = parser:language_for_range({ line, col, line, col })
	if lang_tree and type(lang_tree.lang) == "function" then
		local lang = lang_tree:lang()
		-- Return the detected language if it's different from the base filetype
		if lang and lang ~= base_filetype then
			return lang
		end
	end

	-- If language injection doesn't provide a different language, try to get the
	-- tree at cursor position and check if it's in a different parser context
	local tree_for_range = parser:tree_for_range({ line, col, line, col }, { include_children = true })
	if tree_for_range and type(tree_for_range.lang) == "function" then
		-- Get the root language of this tree
		local tree_lang = tree_for_range:lang()
		if tree_lang and tree_lang ~= base_filetype then
			return tree_lang
		end
	end

	-- Check if there are any child parsers (injected languages)
	local children = parser:children()
	for _, child_parser in pairs(children) do
		if child_parser and type(child_parser.lang) == "function" then
			local child_lang = child_parser:lang()
			if child_lang then
				-- Check if cursor is within this child parser's range
				local child_trees = child_parser:trees()
				for _, child_tree in ipairs(child_trees) do
					local root = child_tree:root()
					local start_row, start_col, end_row, end_col = root:range()

					-- Check if cursor is within this child tree's range
					if line >= start_row and line <= end_row then
						if line == start_row and col < start_col then
							-- Before start
						elseif line == end_row and col > end_col then
							-- After end
						else
							-- Within range
							return child_lang
						end
					end
				end
			end
		end
	end

	-- No injected language found, return base filetype
	return base_filetype
end

-- Main function to detect the current language at cursor position
function M.detect_language()
	local current_buffer = vim.api.nvim_get_current_buf()
	local current_filetype = vim.bo.filetype
	local line, col = get_cursor_position()
	local current_time = vim.fn.localtime()

	-- Check cache validity (buffer, filetype, and position-based)
	-- Cache is valid for configured timeout and same buffer/filetype/approximate position
	local cache_timeout = get_cache_timeout()
	if
		language_cache.buffer == current_buffer
		and language_cache.filetype == current_filetype
		and language_cache.timestamp + cache_timeout > current_time
		and math.abs(language_cache.last_line - line) <= 5
		and math.abs(language_cache.last_col - col) <= 10
	then
		return language_cache.language
	end

	-- Fast path: for most files without embedded languages, just use filetype
	-- Only do expensive TreeSitter detection for known embedding contexts
	local needs_treesitter = current_filetype == "html"
		or current_filetype == "vue"
		or current_filetype == "svelte"
		or current_filetype == "markdown"
		or current_filetype == "jsx"
		or current_filetype == "tsx"
		or current_filetype == "astro"

	local detected_lang
	if needs_treesitter then
		detected_lang = detect_language_at_cursor()
	else
		detected_lang = current_filetype
	end

	-- Update cache
	language_cache.buffer = current_buffer
	language_cache.filetype = current_filetype
	language_cache.last_line = line
	language_cache.last_col = col
	language_cache.language = detected_lang
	language_cache.timestamp = current_time

	return detected_lang
end

-- Function to get supported embedded languages for a given filetype
-- This is now more dynamic - it discovers available injected languages
function M.get_supported_languages(filetype)
	local languages = { filetype }

	-- Try to get parser and check for injected languages
	local has_parser, parser = pcall(vim.treesitter.get_parser, 0)
	if has_parser and parser then
		local children = parser:children()
		for _, child_parser in pairs(children) do
			if child_parser and type(child_parser.lang) == "function" then
				local child_lang = child_parser:lang()
				if child_lang and child_lang ~= filetype then
					-- Add to supported languages if not already present
					local found = false
					for _, lang in ipairs(languages) do
						if lang == child_lang then
							found = true
							break
						end
					end
					if not found then
						table.insert(languages, child_lang)
					end
				end
			end
		end
	end

	return languages
end

return M
