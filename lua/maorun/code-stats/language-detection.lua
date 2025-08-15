local M = {}

-- Get the current cursor position
local function get_cursor_position()
	local cursor = vim.api.nvim_win_get_cursor(0)
	return cursor[1] - 1, cursor[2] -- Convert to 0-indexed for treesitter
end

-- Check if a node or its ancestors match any of the given node types
local function is_node_type(node, types)
	if not node then
		return false
	end

	local node_type = node:type()
	for _, type_name in ipairs(types) do
		if node_type == type_name then
			return true
		end
	end
	return false
end

-- Get the language from script tag attributes using treesitter
local function get_script_language(script_node)
	-- Default to javascript for script tags
	local default_lang = "javascript"

	-- Look for type attribute in script tag
	for child in script_node:iter_children() do
		if child:type() == "attribute" then
			local attr_name = nil
			local attr_value = nil

			for attr_child in child:iter_children() do
				if attr_child:type() == "attribute_name" then
					attr_name = vim.treesitter.get_node_text(attr_child, 0)
				elseif attr_child:type() == "quoted_attribute_value" then
					attr_value = vim.treesitter.get_node_text(attr_child, 0)
					-- Remove quotes from value
					attr_value = attr_value:gsub("^[\"']", ""):gsub("[\"']$", "")
				end
			end

			if attr_name == "type" and attr_value then
				-- Check for JavaScript types
				if attr_value:match("javascript") or attr_value:match("application/javascript") then
					return "javascript"
				elseif attr_value:match("module") then
					return "javascript"
				end
			end
		end
	end

	return default_lang
end

-- Get the language from style tag attributes using treesitter
local function get_style_language(style_node)
	-- Default to css for style tags
	local default_lang = "css"

	-- Look for type attribute in style tag
	for child in style_node:iter_children() do
		if child:type() == "attribute" then
			local attr_name = nil
			local attr_value = nil

			for attr_child in child:iter_children() do
				if attr_child:type() == "attribute_name" then
					attr_name = vim.treesitter.get_node_text(attr_child, 0)
				elseif attr_child:type() == "quoted_attribute_value" then
					attr_value = vim.treesitter.get_node_text(attr_child, 0)
					-- Remove quotes from value
					attr_value = attr_value:gsub("^[\"']", ""):gsub("[\"']$", "")
				end
			end

			if attr_name == "type" and attr_value then
				-- Check for CSS types
				if attr_value:match("css") then
					return "css"
				end
			end
		end
	end

	return default_lang
end

-- Check if cursor is within any embedded language block using treesitter
local function detect_embedded_language(filetype)
	-- Only check for embedded languages in HTML files
	if filetype ~= "html" then
		return filetype
	end

	-- Check if treesitter is available for HTML
	local has_parser, parser = pcall(vim.treesitter.get_parser, 0, "html")
	if not has_parser or not parser then
		-- Fallback to original filetype if no treesitter parser
		return filetype
	end

	local line, col = get_cursor_position()
	local tree = parser:parse()[1]
	local root = tree:root()

	-- Get the node at cursor position
	local node = root:named_descendant_for_range(line, col, line, col)

	-- Walk up the tree to find if we're inside script or style elements
	local current = node
	while current do
		local node_type = current:type()

		if node_type == "script_element" then
			-- We're inside a script tag, check for language type
			return get_script_language(current)
		elseif node_type == "style_element" then
			-- We're inside a style tag, check for language type
			return get_style_language(current)
		elseif is_node_type(current, { "raw_text", "text" }) then
			-- Check if this text node is inside script or style
			local parent = current:parent()
			if parent then
				local parent_type = parent:type()
				if parent_type == "script_element" then
					return get_script_language(parent)
				elseif parent_type == "style_element" then
					return get_style_language(parent)
				end
			end
		end

		current = current:parent()
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
