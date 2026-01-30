-- mobius.lua - plugin entry point
--
-- Normal mode uses g@ operator for native dot-repeat (.). Callbacks and trigger
-- live in mobius module (require("mobius")); operatorfunc points at _G.mobius_operator_callback.

local function plug_opts()
	return { noremap = true, silent = true }
end

-- -----------------------------------------------------------------------------
-- Normal mode: <Plug> mappings (operator g@ + feed g@l)
-- -----------------------------------------------------------------------------
vim.keymap.set(
	"n",
	"<Plug>(MobiusIncrement)",
	":<c-u>lua require('mobius').operator_trigger('increment', false)()<CR>",
	plug_opts()
)
vim.keymap.set(
	"n",
	"<Plug>(MobiusDecrement)",
	":<c-u>lua require('mobius').operator_trigger('decrement', false)()<CR>",
	plug_opts()
)
vim.keymap.set(
	"n",
	"<Plug>(MobiusIncrementCumulative)",
	":<c-u>lua require('mobius').operator_trigger('increment', true)()<CR>",
	plug_opts()
)
vim.keymap.set(
	"n",
	"<Plug>(MobiusDecrementCumulative)",
	":<c-u>lua require('mobius').operator_trigger('decrement', true)()<CR>",
	plug_opts()
)

-- -----------------------------------------------------------------------------
-- Visual mode: <Plug> mappings (lazy-load via mobius.execute)
-- -----------------------------------------------------------------------------
vim.keymap.set(
	"x",
	"<Plug>(MobiusIncrement)",
	":<c-u>lua require('mobius').execute('increment', { visual = true, seqadd = false, step = vim.v.count1 })<CR>",
	plug_opts()
)
vim.keymap.set(
	"x",
	"<Plug>(MobiusDecrement)",
	":<c-u>lua require('mobius').execute('decrement', { visual = true, seqadd = false, step = vim.v.count1 })<CR>",
	plug_opts()
)
vim.keymap.set(
	"x",
	"<Plug>(MobiusIncrementSeq)",
	":<c-u>lua require('mobius').execute('increment', { visual = true, seqadd = true, step = vim.v.count1 })<CR>",
	plug_opts()
)
vim.keymap.set(
	"x",
	"<Plug>(MobiusDecrementSeq)",
	":<c-u>lua require('mobius').execute('decrement', { visual = true, seqadd = true, step = vim.v.count1 })<CR>",
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
