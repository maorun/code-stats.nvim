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

	it("should return original filetype when treesitter is not available", function()
		_G.vim.bo.filetype = "lua"
		_G.vim.treesitter.get_parser = function()
			error("No parser available")
		end

		local result = lang_detection.detect_language()
		assert.are.equal("lua", result)
	end)

	it("should return base filetype when no language injection is found", function()
		_G.vim.bo.filetype = "html"

		-- Mock parser with no language injection
		local mock_parser = {
			language_for_range = function()
				return nil -- No injected language
			end,
			tree_for_range = function()
				return nil -- No specific tree
			end,
			children = function()
				return {} -- No child parsers
			end,
		}

		_G.vim.treesitter.get_parser = function()
			return mock_parser
		end

		local result = lang_detection.detect_language()
		assert.are.equal("html", result)
	end)

	it("should detect injected language using language_for_range", function()
		_G.vim.bo.filetype = "html"

		-- Mock a language tree that returns a different language
		local mock_lang_tree = {
			lang = function()
				return "javascript"
			end,
		}

		local mock_parser = {
			language_for_range = function()
				return mock_lang_tree
			end,
			tree_for_range = function()
				return nil
			end,
			children = function()
				return {}
			end,
		}

		_G.vim.treesitter.get_parser = function()
			return mock_parser
		end

		local result = lang_detection.detect_language()
		assert.are.equal("javascript", result)
	end)

	it("should detect language using tree_for_range when language_for_range returns same filetype", function()
		_G.vim.bo.filetype = "html"

		-- Mock language tree that returns same as base filetype
		local mock_lang_tree = {
			lang = function()
				return "html"
			end,
		}

		-- Mock tree for range that returns different language
		local mock_tree = {
			lang = function()
				return "css"
			end,
		}

		local mock_parser = {
			language_for_range = function()
				return mock_lang_tree
			end,
			tree_for_range = function()
				return mock_tree
			end,
			children = function()
				return {}
			end,
		}

		_G.vim.treesitter.get_parser = function()
			return mock_parser
		end

		local result = lang_detection.detect_language()
		assert.are.equal("css", result)
	end)

	it("should detect language from child parsers when cursor is in range", function()
		_G.vim.bo.filetype = "html"
		_G.vim.api.nvim_win_get_cursor = function()
			return { 5, 10 } -- cursor at line 5, col 10 (1-indexed)
		end

		-- Mock root node that covers the cursor position
		local mock_root = {
			range = function()
				return 4, 5, 6, 15 -- lines 4-6, cols 5-15 (0-indexed)
			end,
		}

		-- Mock child tree
		local mock_child_tree = {
			root = function()
				return mock_root
			end,
		}

		-- Mock child parser
		local mock_child_parser = {
			lang = function()
				return "javascript"
			end,
			trees = function()
				return { mock_child_tree }
			end,
		}

		local mock_parser = {
			language_for_range = function()
				return nil
			end,
			tree_for_range = function()
				return nil
			end,
			children = function()
				return { mock_child_parser }
			end,
		}

		_G.vim.treesitter.get_parser = function()
			return mock_parser
		end

		local result = lang_detection.detect_language()
		assert.are.equal("javascript", result)
	end)

	it("should not detect language from child parsers when cursor is outside range", function()
		_G.vim.bo.filetype = "html"
		_G.vim.api.nvim_win_get_cursor = function()
			return { 10, 5 } -- cursor at line 10, col 5 (1-indexed)
		end

		-- Mock root node that does not cover the cursor position
		local mock_root = {
			range = function()
				return 4, 5, 6, 15 -- lines 4-6, cols 5-15 (0-indexed), cursor is at line 9 (0-indexed)
			end,
		}

		-- Mock child tree
		local mock_child_tree = {
			root = function()
				return mock_root
			end,
		}

		-- Mock child parser
		local mock_child_parser = {
			lang = function()
				return "javascript"
			end,
			trees = function()
				return { mock_child_tree }
			end,
		}

		local mock_parser = {
			language_for_range = function()
				return nil
			end,
			tree_for_range = function()
				return nil
			end,
			children = function()
				return { mock_child_parser }
			end,
		}

		_G.vim.treesitter.get_parser = function()
			return mock_parser
		end

		local result = lang_detection.detect_language()
		assert.are.equal("html", result) -- Should fall back to base filetype
	end)

	it("should return supported languages including injected ones", function()
		_G.vim.bo.filetype = "html"

		-- Mock child parsers for CSS and JavaScript
		local mock_css_parser = {
			lang = function()
				return "css"
			end,
		}

		local mock_js_parser = {
			lang = function()
				return "javascript"
			end,
		}

		local mock_parser = {
			children = function()
				return { mock_css_parser, mock_js_parser }
			end,
		}

		_G.vim.treesitter.get_parser = function()
			return mock_parser
		end

		local supported = lang_detection.get_supported_languages("html")
		-- Should include base filetype and all injected languages
		assert.are.same({ "html", "css", "javascript" }, supported)
	end)

	it("should return only base language when no injected languages exist", function()
		_G.vim.bo.filetype = "lua"

		local mock_parser = {
			children = function()
				return {} -- No child parsers
			end,
		}

		_G.vim.treesitter.get_parser = function()
			return mock_parser
		end

		local supported = lang_detection.get_supported_languages("lua")
		assert.are.same({ "lua" }, supported)
	end)

	it("should handle treesitter errors gracefully in get_supported_languages", function()
		_G.vim.treesitter.get_parser = function()
			error("No parser available")
		end

		local supported = lang_detection.get_supported_languages("markdown")
		assert.are.same({ "markdown" }, supported)
	end)
end)
