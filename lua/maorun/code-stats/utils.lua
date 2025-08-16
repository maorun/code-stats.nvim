-- Shared utility functions for Code::Stats plugin

local utils = {}

-- Calculate level from XP using standard gaming formula
-- Level = floor(sqrt(XP / 100)) + 1
utils.calculateLevel = function(xp)
	if not xp or xp <= 0 then
		return 1
	end
	return math.floor(math.sqrt(xp / 100)) + 1
end

-- Calculate XP required for a specific level
utils.calculateXpForLevel = function(level)
	if not level or level <= 1 then
		return 0
	end
	return (level - 1) * (level - 1) * 100
end

return utils
