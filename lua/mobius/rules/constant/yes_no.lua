---@return mobius.Rule
return require("mobius.rules.constant")({
	elements = { { "yes", "no" }, { "Yes", "No" }, { "YES", "NO" } },
	word = true,
})
