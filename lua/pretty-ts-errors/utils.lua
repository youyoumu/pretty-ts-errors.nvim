local M = {}
local api = vim.api

function M.log_to_file(msg)
	local log_file = "/tmp/nvim_plugin.log" -- Change this path as needed
	local file = io.open(log_file, "a") -- Open file in append mode
	if file then
		file:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. msg .. "\n")
		file:close()
	else
		vim.api.nvim_echo({ { "Failed to open log file: " .. log_file, "ErrorMsg" } }, true, {})
	end
end

function M.update_buffer(buf, contents)
	if api.nvim_buf_is_valid(buf) then
		api.nvim_set_option_value("modifiable", true, { buf = buf })
		api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(contents, "\n"))
		api.nvim_set_option_value("modifiable", false, { buf = buf })
	end
end

return M
