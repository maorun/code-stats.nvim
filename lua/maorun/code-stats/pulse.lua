local pulse = {
	xps = {},
}

-- Get the path for persisting XP data
local function get_persistence_path()
	local data_dir = vim.fn.stdpath("data")
	return data_dir .. "/code-stats-xp.json"
end

-- Save XP data to file (only if there are XP values > 0)
pulse.save = function()
	local has_xp = false
	for _, xp in pairs(pulse.xps) do
		if xp > 0 then
			has_xp = true
			break
		end
	end

	if not has_xp then
		-- Remove persistence file if no XP to save
		local file_path = get_persistence_path()
		vim.fn.delete(file_path)
		return
	end

	local file_path = get_persistence_path()
	local data = vim.fn.json_encode(pulse.xps)
	local file = io.open(file_path, "w")
	if file then
		file:write(data)
		file:close()
	end
end

-- Load XP data from file and merge with current XP
pulse.load = function()
	local file_path = get_persistence_path()
	local file = io.open(file_path, "r")
	if not file then
		return -- No persisted data
	end

	local content = file:read("*all")
	file:close()

	if content and content ~= "" then
		local ok, loaded_xps = pcall(vim.fn.json_decode, content)
		if ok and type(loaded_xps) == "table" then
			-- Merge loaded XP with current XP
			for lang, xp in pairs(loaded_xps) do
				if type(xp) == "number" and xp > 0 then
					pulse.xps[lang] = pulse.getXp(lang) + xp
				end
			end
			-- Remove the persistence file after loading
			vim.fn.delete(file_path)
		end
	end
end

pulse.addXp = function(lang, amount)
	pulse.xps[lang] = pulse.getXp(lang) + amount
end

pulse.getXp = function(lang)
	if pulse.xps[lang] then
		return pulse.xps[lang]
	end
	return 0
end

pulse.reset = function()
	pulse.xps = {}
	-- Also remove persistence file when resetting
	local file_path = get_persistence_path()
	vim.fn.delete(file_path)
end

return pulse
