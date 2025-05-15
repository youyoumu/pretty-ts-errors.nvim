local M = {}
local api = vim.api

local config = require("pretty-ts-errors.config")
local diagnostics = require("pretty-ts-errors.diagnostics")

-- prevent breaking changes
function M.show_formatted_error()
	diagnostics.show_formatted_error()
end
function M.open_all_errors()
	diagnostics.open_all_errors()
end
function M.toggle_auto_open()
	diagnostics.toggle_auto_open()
end

-- Setup function to initialize the plugin
function M.setup(opts)
	config.setup(opts)

	api.nvim_create_user_command("PrettyTsError", function()
		diagnostics.show_formatted_error()
	end, {})

	api.nvim_create_user_command("PrettyTsErrors", function()
		diagnostics.open_all_errors()
	end, {})

	api.nvim_create_user_command("PrettyTsToggleAuto", function()
		diagnostics.toggle_auto_open()
	end, {})

	if config.get().auto_open then
		diagnostics.enable_auto_open()
	end
end

return M
