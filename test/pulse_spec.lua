describe("Pulse", function()
	local pulse

	before_each(function()
		-- Mock vim environment before requiring modules
		_G.vim = _G.vim or {}
		_G.vim.fn = _G.vim.fn or {}
		_G.vim.fn.stdpath = function(what)
			if what == "data" then
				return "/tmp"
			end
			return "/tmp"
		end

		-- Reset the pulse module before each test to ensure a clean state
		-- This is important because Lua modules often retain state.
		package.loaded["maorun.code-stats.pulse"] = nil
		package.loaded["maorun.code-stats.logging"] = nil
		pulse = require("maorun.code-stats.pulse")
	end)

	it("should add XP to a language", function()
		pulse.addXp("lua", 10)
		assert.are.equal(10, pulse.getXp("lua"))
	end)

	it("should return 0 XP for a language not yet added", function()
		assert.are.equal(0, pulse.getXp("python"))
	end)

	it("should add XP to multiple languages", function()
		pulse.addXp("lua", 10)
		pulse.addXp("python", 20)
		assert.are.equal(10, pulse.getXp("lua"))
		assert.are.equal(20, pulse.getXp("python"))
	end)

	it("should correctly add XP multiple times to the same language", function()
		pulse.addXp("lua", 10)
		pulse.addXp("lua", 5)
		assert.are.equal(15, pulse.getXp("lua"))
	end)

	it("should reset all XP", function()
		pulse.addXp("lua", 10)
		pulse.addXp("python", 20)
		pulse.reset()
		assert.are.equal(0, pulse.getXp("lua"))
		assert.are.equal(0, pulse.getXp("python"))
	end)

	it("should handle adding zero XP", function()
		pulse.addXp("go", 0)
		assert.are.equal(0, pulse.getXp("go"))
	end)

	it("should handle adding negative XP (if that's considered valid)", function()
		-- Assuming negative XP could be a use case, e.g. penalties
		pulse.addXp("ruby", -5)
		assert.are.equal(-5, pulse.getXp("ruby"))
		pulse.addXp("ruby", 10)
		assert.are.equal(5, pulse.getXp("ruby"))
	end)

	it("should save and load XP data (basic persistence)", function()
		-- Mock minimal vim functions for persistence test
		local mock_file_data = nil
		_G.vim = _G.vim or {}
		_G.vim.fn = _G.vim.fn or {}
		local original_stdpath = _G.vim.fn.stdpath
		local original_json_encode = _G.vim.fn.json_encode
		local original_json_decode = _G.vim.fn.json_decode
		local original_delete = _G.vim.fn.delete

		_G.vim.fn.stdpath = function()
			return "/tmp/test"
		end
		_G.vim.fn.json_encode = function(data)
			return '{"lua":' .. (data.lua or 0) .. "}"
		end
		_G.vim.fn.json_decode = function(str)
			if str == '{"lua":10}' then
				return { lua = 10 }
			end
			return {}
		end
		_G.vim.fn.delete = function() end

		-- Mock io.open
		local original_io_open = io.open
		io.open = function(path, mode)
			if mode == "w" then
				return {
					write = function(_, data)
						mock_file_data = data
					end,
					close = function() end,
				}
			elseif mode == "r" and mock_file_data then
				return {
					read = function()
						return mock_file_data
					end,
					close = function() end,
				}
			end
			return nil
		end

		-- Test save
		pulse.addXp("lua", 10)
		pulse.save()
		assert.is_not_nil(mock_file_data)

		-- Test load
		pulse.reset()
		mock_file_data = '{"lua":10}'
		pulse.load()
		assert.are.equal(10, pulse.getXp("lua"))

		-- Restore original functions
		io.open = original_io_open
		_G.vim.fn.stdpath = original_stdpath
		_G.vim.fn.json_encode = original_json_encode
		_G.vim.fn.json_decode = original_json_decode
		_G.vim.fn.delete = original_delete
	end)
end)
