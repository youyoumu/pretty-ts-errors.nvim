local M = {}
local api = vim.api

local config = require("pretty-ts-errors.config")
local utils = require("pretty-ts-errors.utils")
local diagnostics = require("pretty-ts-errors.diagnostics")

function M.enable_auto_open()
	local group = api.nvim_create_augroup("PrettyTsErrorsAuto", { clear = true })
	api.nvim_create_autocmd("CursorHold", {
		pattern = { "*.ts", "*.tsx", "*.js", "*.jsx" },
		group = group,
		callback = function()
			local line = api.nvim_win_get_cursor(0)[1] - 1
			local has_ts_error = false

			for _, diagnostic in ipairs(vim.diagnostic.get(0, { lnum = line })) do
				if utils.is_ts_source(diagnostic.source) then
					has_ts_error = true
					break
				end
			end

			if has_ts_error then
				diagnostics.show_formatted_error()
			end
		end,
	})
end

function M.toggle_auto_open()
	-- Toggle the auto_open setting
	config.get().auto_open = not config.get().auto_open

	-- Clear existing autocommand group if it exists
	api.nvim_create_augroup("PrettyTsErrorsAuto", { clear = true })

	-- If auto_open is now enabled, recreate the autocommands
	if config.get().auto_open then
		M.enable_auto_open()
		vim.notify("TypeScript error auto-display on hover: Enabled", vim.log.levels.INFO)
	else
		vim.notify("TypeScript error auto-display on hover: Disabled", vim.log.levels.INFO)
	end
end

-- Setup function to initialize the plugin
function M.setup(opts)
	-- Merge user options with defaults
	config.setup(opts)

	api.nvim_create_user_command("PrettyTsError", function()
		diagnostics.show_formatted_error()
	end, {})

	api.nvim_create_user_command("PrettyTsErrors", function()
		diagnostics.open_all_errors()
	end, {})

	api.nvim_create_user_command("PrettyTsToggleAuto", function()
		M.toggle_auto_open()
	end, {})

	if config.get().auto_open then
		M.enable_auto_open()
	end
end

return M
