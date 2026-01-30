-- Constants for nvim-mobius engine
-- Centralizes magic numbers used in scoring and validation

---@class mobius.engine.constants
---@field SCORE_CONTAINS_CURSOR number
---@field SCORE_AFTER_CURSOR_BASE number
---@field SCORE_BEFORE_CURSOR_BASE number
---@field SCORE_LENGTH_MULTIPLIER number
---@field SCORE_PRIORITY_MULTIPLIER number
---@field DEFAULT_PRIORITY number
---@field MAX_HEADER_LEVEL number
---@field MIN_HEADER_LEVEL number
---@field RGB_MIN number
---@field RGB_MAX number

local M = {} ---@type mobius.engine.constants

-- Scoring constants
-- Base score when match contains cursor position
M.SCORE_CONTAINS_CURSOR = 1000

-- Base score for match after cursor (minus distance)
M.SCORE_AFTER_CURSOR_BASE = 100

-- Base score for match before cursor (minus distance)
M.SCORE_BEFORE_CURSOR_BASE = -100

-- Multiplier for match length in scoring
M.SCORE_LENGTH_MULTIPLIER = 0.1

-- Multiplier for rule priority in scoring
M.SCORE_PRIORITY_MULTIPLIER = 0.01

-- Default priority for rules without explicit priority
M.DEFAULT_PRIORITY = 50

-- Boundary constants
-- Maximum markdown header level (######)
M.MAX_HEADER_LEVEL = 6

-- Minimum markdown header level (#)
M.MIN_HEADER_LEVEL = 1

-- RGB color boundaries
M.RGB_MIN = 0
M.RGB_MAX = 255

---@cast M mobius.engine.constants
return M
