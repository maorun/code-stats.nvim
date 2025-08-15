describe("Language Detection", function()
	local lang_detection

	before_each(function()
		-- Reset the module before each test
		package.loaded["maorun.code-stats.language-detection"] = nil
		lang_detection = require("maorun.code-stats.language-detection")

		-- Mock vim environment
		_G.vim = _G.vim or {}
		_G.vim.bo = { filetype = "html" }
		_G.vim.api = _G.vim.api or {}
		_G.vim.treesitter = _G.vim.treesitter or {}

		-- Mock cursor position
		_G.vim.api.nvim_win_get_cursor = function()
			return { 1, 0 }
		end
	end)

	it("should return original filetype for non-HTML files", function()
		_G.vim.bo.filetype = "lua"
		local result = lang_detection.detect_language()
		assert.are.equal("lua", result)
	end)

	it("should fallback to HTML when treesitter is not available", function()
		_G.vim.treesitter.get_parser = function()
			error("No parser available")
		end

		local result = lang_detection.detect_language()
		assert.are.equal("html", result)
	end)

	it("should detect HTML as base language when not in embedded content", function()
		-- Mock treesitter parser and tree
		local mock_node = {
			type = function()
				return "element"
			end,
			parent = function()
				return nil
			end,
		}

		local mock_root = {
			named_descendant_for_range = function()
				return mock_node
			end,
		}

		local mock_tree = {
			root = function()
				return mock_root
			end,
		}

		local mock_parser = {
			parse = function()
				return { mock_tree }
			end,
		}

		_G.vim.treesitter.get_parser = function()
			return mock_parser
		end
		_G.vim.api.nvim_win_get_cursor = function()
			return { 3, 5 }
		end

		local result = lang_detection.detect_language()
		assert.are.equal("html", result)
	end)

	it("should detect JavaScript inside script elements", function()
		-- Mock a script element node
		local mock_script_node = {
			type = function()
				return "script_element"
			end,
			iter_children = function()
				return function() end
			end,
			parent = function()
				return nil
			end,
		}

		local mock_root = {
			named_descendant_for_range = function()
				return mock_script_node
			end,
		}

		local mock_tree = {
			root = function()
				return mock_root
			end,
		}

		local mock_parser = {
			parse = function()
				return { mock_tree }
			end,
		}

		_G.vim.treesitter.get_parser = function()
			return mock_parser
		end
		_G.vim.api.nvim_win_get_cursor = function()
			return { 3, 5 }
		end

		local result = lang_detection.detect_language()
		assert.are.equal("javascript", result)
	end)

	it("should detect CSS inside style elements", function()
		-- Mock a style element node
		local mock_style_node = {
			type = function()
				return "style_element"
			end,
			iter_children = function()
				return function() end
			end,
			parent = function()
				return nil
			end,
		}

		local mock_root = {
			named_descendant_for_range = function()
				return mock_style_node
			end,
		}

		local mock_tree = {
			root = function()
				return mock_root
			end,
		}

		local mock_parser = {
			parse = function()
				return { mock_tree }
			end,
		}

		_G.vim.treesitter.get_parser = function()
			return mock_parser
		end
		_G.vim.api.nvim_win_get_cursor = function()
			return { 3, 10 }
		end

		local result = lang_detection.detect_language()
		assert.are.equal("css", result)
	end)

	it("should detect JavaScript in text nodes inside script elements", function()
		-- Mock a text node inside script element
		local mock_script_parent = {
			type = function()
				return "script_element"
			end,
			iter_children = function()
				return function() end
			end,
			parent = function()
				return nil
			end,
		}

		local mock_text_node = {
			type = function()
				return "raw_text"
			end,
			parent = function()
				return mock_script_parent
			end,
		}

		local mock_root = {
			named_descendant_for_range = function()
				return mock_text_node
			end,
		}

		local mock_tree = {
			root = function()
				return mock_root
			end,
		}

		local mock_parser = {
			parse = function()
				return { mock_tree }
			end,
		}

		_G.vim.treesitter.get_parser = function()
			return mock_parser
		end
		_G.vim.api.nvim_win_get_cursor = function()
			return { 3, 2 }
		end

		local result = lang_detection.detect_language()
		assert.are.equal("javascript", result)
	end)

	it("should detect CSS in text nodes inside style elements", function()
		-- Mock a text node inside style element
		local mock_style_parent = {
			type = function()
				return "style_element"
			end,
			iter_children = function()
				return function() end
			end,
			parent = function()
				return nil
			end,
		}

		local mock_text_node = {
			type = function()
				return "text"
			end,
			parent = function()
				return mock_style_parent
			end,
		}

		local mock_root = {
			named_descendant_for_range = function()
				return mock_text_node
			end,
		}

		local mock_tree = {
			root = function()
				return mock_root
			end,
		}

		local mock_parser = {
			parse = function()
				return { mock_tree }
			end,
		}

		_G.vim.treesitter.get_parser = function()
			return mock_parser
		end
		_G.vim.api.nvim_win_get_cursor = function()
			return { 3, 5 }
		end

		local result = lang_detection.detect_language()
		assert.are.equal("css", result)
	end)

	it("should handle script tags with type attributes", function()
		-- Mock a script element with type attribute
		local mock_attr_value_node = {
			type = function()
				return "quoted_attribute_value"
			end,
		}

		local mock_attr_name_node = {
			type = function()
				return "attribute_name"
			end,
		}

		local mock_attr_node = {
			type = function()
				return "attribute"
			end,
			iter_children = function()
				local i = 0
				local children = { mock_attr_name_node, mock_attr_value_node }
				return function()
					i = i + 1
					return children[i]
				end
			end,
		}

		local mock_script_node = {
			type = function()
				return "script_element"
			end,
			iter_children = function()
				local i = 0
				local children = { mock_attr_node }
				return function()
					i = i + 1
					return children[i]
				end
			end,
			parent = function()
				return nil
			end,
		}

		local mock_root = {
			named_descendant_for_range = function()
				return mock_script_node
			end,
		}

		local mock_tree = {
			root = function()
				return mock_root
			end,
		}

		local mock_parser = {
			parse = function()
				return { mock_tree }
			end,
		}

		-- Mock treesitter get_node_text function
		_G.vim.treesitter.get_node_text = function(node, bufnr)
			if node == mock_attr_name_node then
				return "type"
			elseif node == mock_attr_value_node then
				return '"text/javascript"'
			end
			return ""
		end

		_G.vim.treesitter.get_parser = function()
			return mock_parser
		end
		_G.vim.api.nvim_win_get_cursor = function()
			return { 3, 2 }
		end

		local result = lang_detection.detect_language()
		assert.are.equal("javascript", result)
	end)

	it("should return supported languages for HTML files", function()
		local supported = lang_detection.get_supported_languages("html")
		assert.are.same({ "html", "css", "javascript" }, supported)
	end)

	it("should return single language for non-HTML files", function()
		local supported = lang_detection.get_supported_languages("lua")
		assert.are.same({ "lua" }, supported)
	end)
end)
