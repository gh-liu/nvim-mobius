-- mobius.lua - plugin entry point
--
-- Normal mode uses g@ operator for native dot-repeat (.). Callbacks and trigger
-- live in lua/mobius/plugin/mobius.lua; operatorfunc points at _G.mobius_operator_callback.

local mobius_plugin = require("mobius.plugin.mobius")

local function plug_opts()
	return { noremap = true, silent = true }
end

-- -----------------------------------------------------------------------------
-- Normal mode: <Plug> mappings (operator g@ + feed g@l)
-- -----------------------------------------------------------------------------
vim.keymap.set("n", "<Plug>(MobiusIncrement)", mobius_plugin.operator_trigger("increment", false), plug_opts())
vim.keymap.set("n", "<Plug>(MobiusDecrement)", mobius_plugin.operator_trigger("decrement", false), plug_opts())
vim.keymap.set("n", "<Plug>(MobiusIncrementCumulative)", mobius_plugin.operator_trigger("increment", true), plug_opts())
vim.keymap.set("n", "<Plug>(MobiusDecrementCumulative)", mobius_plugin.operator_trigger("decrement", true), plug_opts())

-- Default keybindings (drop-in for Vim <C-a>/<C-x>); override in config if needed
vim.keymap.set("n", "<C-a>", "<Plug>(MobiusIncrement)", plug_opts())
vim.keymap.set("n", "<C-x>", "<Plug>(MobiusDecrement)", plug_opts())
vim.keymap.set("n", "g<C-a>", "<Plug>(MobiusIncrementCumulative)", plug_opts())
vim.keymap.set("n", "g<C-x>", "<Plug>(MobiusDecrementCumulative)", plug_opts())
vim.keymap.set("x", "<C-a>", "<Plug>(MobiusIncrement)", plug_opts())
vim.keymap.set("x", "<C-x>", "<Plug>(MobiusDecrement)", plug_opts())
vim.keymap.set("x", "g<C-a>", "<Plug>(MobiusIncrementSeq)", plug_opts())
vim.keymap.set("x", "g<C-x>", "<Plug>(MobiusDecrementSeq)", plug_opts())

-- -----------------------------------------------------------------------------
-- Visual mode: <Plug> mappings (direct engine.execute; same/sequential addend)
-- -----------------------------------------------------------------------------
vim.keymap.set(
	"x",
	"<Plug>(MobiusIncrement)",
	":<c-u>lua require('mobius.engine').execute('increment', { visual = true, seqadd = false, step = vim.v.count1 })<CR>",
	plug_opts()
)
vim.keymap.set(
	"x",
	"<Plug>(MobiusDecrement)",
	":<c-u>lua require('mobius.engine').execute('decrement', { visual = true, seqadd = false, step = vim.v.count1 })<CR>",
	plug_opts()
)
vim.keymap.set(
	"x",
	"<Plug>(MobiusIncrementSeq)",
	":<c-u>lua require('mobius.engine').execute('increment', { visual = true, seqadd = true, step = vim.v.count1 })<CR>",
	plug_opts()
)
vim.keymap.set(
	"x",
	"<Plug>(MobiusDecrementSeq)",
	":<c-u>lua require('mobius.engine').execute('decrement', { visual = true, seqadd = true, step = vim.v.count1 })<CR>",
	plug_opts()
)

-- -----------------------------------------------------------------------------
-- Default rules (g:mobius_rules)
-- -----------------------------------------------------------------------------
if not vim.g.mobius_rules then
	vim.g.mobius_rules = {
		"mobius.rules.numeric.integer",
		"mobius.rules.numeric.hex",
		"mobius.rules.numeric.octal",
		"mobius.rules.numeric.decimal_fraction",
		"mobius.rules.constant.bool",
		"mobius.rules.constant.yes_no",
		"mobius.rules.constant.on_off",
		"mobius.rules.date.iso", -- YYYY-MM-DD
		"mobius.rules.date.ymd", -- YYYY/MM/DD
		"mobius.rules.date.mdy", -- MM/DD/YYYY
		"mobius.rules.date.dmy", -- DD/MM/YYYY
		"mobius.rules.date.time_hm", -- HH:MM
		"mobius.rules.date.time_hms", -- HH:MM:SS
		"mobius.rules.paren",
	}
end
