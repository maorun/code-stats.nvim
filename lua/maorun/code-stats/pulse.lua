local pulse = {
	xps = {},
}

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
end

return pulse
