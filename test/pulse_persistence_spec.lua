describe("Pulse Persistence", function()
	local pulse
	local original_io_open
	local mock_files = {}
	local original_vim_fn

	before_each(function()
		-- Reset the pulse module before each test
		package.loaded["maorun.code-stats.pulse"] = nil
		pulse = require("maorun.code-stats.pulse")

		-- Mock vim.fn functions
		original_vim_fn = _G.vim.fn
		_G.vim.fn = {
			stdpath = function(type)
				return "/tmp/test-nvim"
			end,
			json_encode = function(data)
				return vim.fn.json_encode(data)
			end,
			json_decode = function(str)
				return vim.fn.json_decode(str)
			end,
			delete = function(path)
				mock_files[path] = nil
			end,
		}

		-- Mock io.open to use in-memory files
		original_io_open = io.open
		io.open = function(path, mode)
			if mode == "w" then
				return {
					write = function(self, data)
						mock_files[path] = data
					end,
					close = function()
					end,
				}
			elseif mode == "r" then
				if mock_files[path] then
					return {
						read = function(self, format)
							return mock_files[path]
						end,
						close = function()
						end,
					}
				else
					return nil
				end
			end
			return original_io_open(path, mode)
		end

		-- Clear mock files
		mock_files = {}
	end)

	after_each(function()
		-- Restore original functions
		io.open = original_io_open
		_G.vim.fn = original_vim_fn
	end)

	it("should save XP data when there are positive XP values", function()
		pulse.addXp("lua", 10)
		pulse.addXp("python", 5)
		pulse.save()

		local file_path = "/tmp/test-nvim/code-stats-xp.json"
		assert.is_not_nil(mock_files[file_path])

		local saved_data = vim.fn.json_decode(mock_files[file_path])
		assert.are.equal(10, saved_data.lua)
		assert.are.equal(5, saved_data.python)
	end)

	it("should not save XP data when all XP values are zero", function()
		pulse.addXp("lua", 0)
		pulse.addXp("python", 0)
		pulse.save()

		local file_path = "/tmp/test-nvim/code-stats-xp.json"
		assert.is_nil(mock_files[file_path])
	end)

	it("should remove persistence file when saving with no positive XP", function()
		local file_path = "/tmp/test-nvim/code-stats-xp.json"
		mock_files[file_path] = '{"lua":5}'

		pulse.save() -- No XP added, should remove file

		assert.is_nil(mock_files[file_path])
	end)

	it("should load and merge XP data from file", function()
		local file_path = "/tmp/test-nvim/code-stats-xp.json"
		mock_files[file_path] = '{"lua":10,"python":5}'

		pulse.addXp("lua", 2) -- Current XP: lua=2
		pulse.addXp("javascript", 3) -- Current XP: javascript=3

		pulse.load()

		-- Should merge: lua=2+10=12, python=0+5=5, javascript=3+0=3
		assert.are.equal(12, pulse.getXp("lua"))
		assert.are.equal(5, pulse.getXp("python"))
		assert.are.equal(3, pulse.getXp("javascript"))

		-- File should be deleted after loading
		assert.is_nil(mock_files[file_path])
	end)

	it("should handle missing persistence file gracefully", function()
		pulse.addXp("lua", 5)
		pulse.load() -- No file exists

		assert.are.equal(5, pulse.getXp("lua")) -- Should keep current XP
	end)

	it("should handle corrupted persistence file gracefully", function()
		local file_path = "/tmp/test-nvim/code-stats-xp.json"
		mock_files[file_path] = "invalid json data"

		pulse.addXp("lua", 5)
		pulse.load()

		assert.are.equal(5, pulse.getXp("lua")) -- Should keep current XP
		-- File should still exist (not deleted due to corruption)
		assert.is_not_nil(mock_files[file_path])
	end)

	it("should remove persistence file on reset", function()
		local file_path = "/tmp/test-nvim/code-stats-xp.json"
		mock_files[file_path] = '{"lua":10}'

		pulse.addXp("lua", 5)
		pulse.reset()

		assert.are.equal(0, pulse.getXp("lua"))
		assert.is_nil(mock_files[file_path])
	end)

	it("should ignore non-numeric XP values when loading", function()
		local file_path = "/tmp/test-nvim/code-stats-xp.json"
		mock_files[file_path] = '{"lua":10,"python":"invalid","javascript":-5,"go":0}'

		pulse.load()

		assert.are.equal(10, pulse.getXp("lua")) -- Valid positive number
		assert.are.equal(0, pulse.getXp("python")) -- Invalid string ignored
		assert.are.equal(0, pulse.getXp("javascript")) -- Negative ignored
		assert.are.equal(0, pulse.getXp("go")) -- Zero ignored
	end)
end)