local M = {}

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
	if lang_tree then
		local lang = lang_tree:lang()
		-- Return the detected language if it's different from the base filetype
		if lang and lang ~= base_filetype then
			return lang
		end
	end

	-- If language injection doesn't provide a different language, try to get the
	-- tree at cursor position and check if it's in a different parser context
	local tree_for_range = parser:tree_for_range({ line, col, line, col }, { include_children = true })
	if tree_for_range then
		-- Get the root language of this tree
		local tree_lang = tree_for_range:lang()
		if tree_lang and tree_lang ~= base_filetype then
			return tree_lang
		end
	end

	-- Check if there are any child parsers (injected languages)
	local children = parser:children()
	for _, child_parser in pairs(children) do
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

	-- No injected language found, return base filetype
	return base_filetype
end

-- Main function to detect the current language at cursor position
function M.detect_language()
	return detect_language_at_cursor()
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

	return languages
end

return M
