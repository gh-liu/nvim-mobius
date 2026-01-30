-- Numeric rules: integer, decimal, hex, octal, etc.

return {
	integer = require("mobius.rules.numeric.integer"),
	decimal_fraction = require("mobius.rules.numeric.decimal_fraction"),
	hex = require("mobius.rules.numeric.hex"),
	octal = require("mobius.rules.numeric.octal"),
}
