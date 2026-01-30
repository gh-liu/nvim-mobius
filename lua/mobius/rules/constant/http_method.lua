---@return mobius.Rule
return require("mobius.rules.constant")({
	elements = { "GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS" },
	word = true,
})
