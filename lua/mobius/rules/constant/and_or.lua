---@return mobius.Rule
return require("mobius.rules.constant")({
	elements = {
		{ "&&", "||" },
		{ "and", "or" },
		{ "AND", "OR" },
	},
	word = true,
	cyclic = true,
	id = "and_or",
})
