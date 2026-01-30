---@class mobius.RuleMetadata
---@field text string Matched text (required). Other fields may be used by add().

---@class mobius.RuleMatch
---@field col number 0-indexed start column (inclusive).
---@field end_col number 0-indexed end column (inclusive).
---@field metadata mobius.RuleMetadata At least .text; extra fields for add().

---@class mobius.Cursor
---@field row number 0-indexed line
---@field col number 0-indexed column

---@class mobius.Rule
---@field id? string Optional identifier.
---@field priority? number Higher = tried first (default 50).
---@field find fun(cursor: mobius.Cursor): mobius.RuleMatch? find(cursor) -> match or nil.
---@field add fun(addend: number, metadata?: mobius.RuleMetadata): string|{text: string, cursor?: number}? add(addend, metadata) -> new_text or {text, cursor} or nil. cursor = column offset from match start (0 = start).
---@field cyclic? boolean If true, wrap at boundaries (e.g. true <-> false).

--- Built-in rule module path (category). Use for completion when writing string entries in mobius_rules.
---@alias mobius.RuleCat
---| 'mobius.rules.number'
---| 'mobius.rules.hex'
---| 'mobius.rules.hexcolor'
---| 'mobius.rules.bool'
---| 'mobius.rules.yes_no'
---| 'mobius.rules.on_off'
---| 'mobius.rules.case'
---| 'mobius.rules.semver'
---| 'mobius.rules.markdown_header'
---| 'mobius.rules.date'
---| 'mobius.rules.date.dmy'
---| 'mobius.rules.date.iso'
---| 'mobius.rules.date.md'
---| 'mobius.rules.date.mdy'
---| 'mobius.rules.date.ymd'
---| 'mobius.rules.date.time_hm'
---| 'mobius.rules.date.time_hms'

--- Single entry in g:mobius_rules or b:mobius_rules: module path (string), inline rule (table), or factory returning a rule.
--- b:mobius_rules only: first element may be boolean true to mean "inherit" (effective = g:mobius_rules .. b[2..]).
---@alias mobius.RuleSpec mobius.RuleCat|mobius.Rule|string|fun(): mobius.Rule

--- Engine module (require("mobius.engine")).
---@class mobius.Engine
---@field execute fun(direction: "increment"|"decrement", opts?: { visual?: boolean, seqadd?: boolean, step?: number, cumulative?: boolean, rules?: mobius.RuleSpec[] }): nil
---@field repeat_last fun(): nil
---@field clear_cache fun(buf?: number): nil

local M = {}

return M
