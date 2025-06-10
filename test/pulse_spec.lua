describe("Pulse", function()
	local pulse

	before_each(function()
		-- Reset the pulse module before each test to ensure a clean state
		-- This is important because Lua modules often retain state.
		package.loaded["maorun.code-stats.pulse"] = nil
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
end)
