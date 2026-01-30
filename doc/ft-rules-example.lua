-- Filetype-specific mobius rules: one FileType autocmd per language.
-- Uses vim.b[buf].mobius_rules to extend or override vim.g.mobius_rules.
--
-- Two modes:
--   1. Extend: vim.b[buf].mobius_rules = { custom_rule1, custom_rule2, ... } (replaces globals)
--   2. Inherit: vim.b[buf].mobius_rules = { true, custom_rule1, ... } (globals + customs)

local Rules = require("mobius.rules")
local constant = Rules.constant
local markdown_header = require("mobius.rules.markdown_header")
local semver = require("mobius.rules.semver")

-- Go: extend (replace) global rules with Go-specific ones
vim.api.nvim_create_autocmd("FileType", {
	pattern = "go",
	callback = function(event)
		vim.b[event.buf].mobius_rules = {
			true,
			"mobius.rules.constant.and_or",
		}
	end,
})

-- Lua: inherit global rules and add boolean operators

-- Markdown: heading level toggle

-- Rust: inherit global rules and add Rust-specific variants
vim.api.nvim_create_autocmd("FileType", {
	pattern = "rust",
	callback = function(event)
		vim.b[event.buf].mobius_rules = {
			true,
			"mobius.rules.constant.and_or",
			constant({ elements = { "Some", "None" }, word = true }),
			constant({ elements = { "Ok", "Err" }, word = true }),
		}
	end,
})

-- TOML: inherit global rules and add semantic versioning
vim.api.nvim_create_autocmd("FileType", {
	pattern = "toml",
	callback = function(event)
		vim.b[event.buf].mobius_rules = { true, semver() }
	end,
})
