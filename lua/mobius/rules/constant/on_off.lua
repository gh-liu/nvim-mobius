---@return mobius.Rule
return require("mobius.rules.constant")({
	elements = { { "on", "off" }, { "On", "Off" }, { "ON", "OFF" } },
	word = true,
})
