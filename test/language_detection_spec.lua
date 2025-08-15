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

		-- Mock buffer and cursor functions
		_G.vim.api.nvim_win_get_cursor = function()
			return { 1, 0 }
		end
		_G.vim.api.nvim_buf_get_lines = function()
			return { "<html><body></body></html>" }
		end
	end)

	it("should return original filetype for non-HTML files", function()
		_G.vim.bo.filetype = "lua"
		local result = lang_detection.detect_language()
		assert.are.equal("lua", result)
	end)

	it("should detect HTML as base language when not in embedded content", function()
		_G.vim.api.nvim_buf_get_lines = function()
			return { "<html>", "<body>", "<p>Hello World</p>", "</body>", "</html>" }
		end
		_G.vim.api.nvim_win_get_cursor = function()
			return { 3, 5 }
		end -- Inside <p> tag

		local result = lang_detection.detect_language()
		assert.are.equal("html", result)
	end)

	it("should detect JavaScript inside script tags", function()
		_G.vim.api.nvim_buf_get_lines = function()
			return {
				"<html>",
				"<script>",
				"console.log('hello');",
				"</script>",
				"</html>",
			}
		end
		_G.vim.api.nvim_win_get_cursor = function()
			return { 3, 5 }
		end -- Inside script tag

		local result = lang_detection.detect_language()
		assert.are.equal("javascript", result)
	end)

	it("should detect CSS inside style tags", function()
		_G.vim.api.nvim_buf_get_lines = function()
			return {
				"<html>",
				"<style>",
				"body { color: red; }",
				"</style>",
				"</html>",
			}
		end
		_G.vim.api.nvim_win_get_cursor = function()
			return { 3, 10 }
		end -- Inside style tag

		local result = lang_detection.detect_language()
		assert.are.equal("css", result)
	end)

	it("should detect JavaScript in script tags with type attribute", function()
		_G.vim.api.nvim_buf_get_lines = function()
			return {
				"<html>",
				"<script type='text/javascript'>",
				"var x = 1;",
				"</script>",
				"</html>",
			}
		end
		_G.vim.api.nvim_win_get_cursor = function()
			return { 3, 2 }
		end -- Inside script tag

		local result = lang_detection.detect_language()
		assert.are.equal("javascript", result)
	end)

	it("should detect CSS in style tags with type attribute", function()
		_G.vim.api.nvim_buf_get_lines = function()
			return {
				"<html>",
				"<style type='text/css'>",
				".class { margin: 0; }",
				"</style>",
				"</html>",
			}
		end
		_G.vim.api.nvim_win_get_cursor = function()
			return { 3, 5 }
		end -- Inside style tag

		local result = lang_detection.detect_language()
		assert.are.equal("css", result)
	end)

	it("should handle multiple script/style blocks correctly", function()
		_G.vim.api.nvim_buf_get_lines = function()
			return {
				"<html>",
				"<style>body { color: red; }</style>",
				"<p>Some HTML</p>",
				"<script>console.log('test');</script>",
				"</html>",
			}
		end

		-- Test cursor in style block
		_G.vim.api.nvim_win_get_cursor = function()
			return { 2, 15 }
		end
		local result = lang_detection.detect_language()
		assert.are.equal("css", result)

		-- Test cursor in HTML content
		_G.vim.api.nvim_win_get_cursor = function()
			return { 3, 5 }
		end
		result = lang_detection.detect_language()
		assert.are.equal("html", result)

		-- Test cursor in script block
		_G.vim.api.nvim_win_get_cursor = function()
			return { 4, 15 }
		end
		result = lang_detection.detect_language()
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
