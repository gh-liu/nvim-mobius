---@return mobius.Rule
return require("mobius.rules.constant")({
	elements = { { "true", "false" }, { "True", "False" }, { "TRUE", "FALSE" } },
	word = true,
})
