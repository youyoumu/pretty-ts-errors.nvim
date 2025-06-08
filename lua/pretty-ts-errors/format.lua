local M = {}
local utils = require("pretty-ts-errors.utils")
local config = require("pretty-ts-errors.config")

local cache = {}

function M.format_error_async(diagnostic, callback)
	if not utils.is_ts_source(diagnostic.source) then
		callback(nil)
		return
	end

	-- Check cache first
	local cache_key = diagnostic.code .. diagnostic.message
	if cache[cache_key] then
		callback(cache[cache_key])
		return
	end

	local lsp_data = diagnostic.user_data.lsp

	-- Convert to JSON string and escape for shell
	local json_str = vim.fn.json_encode(lsp_data)
	local raw_cmd = config.get().executable
	local cmd = utils.normalize_cmd(raw_cmd)

	-- Use jobstart to run command asynchronously
	local job_id = vim.fn.jobstart(cmd, {
		on_stdout = function(_, data)
			if not data or #data < 1 or (data[1] == "" and #data == 1) then
				return
			end

			local result = table.concat(data, "\n")
			-- Cache the result
			cache[cache_key] = result
			callback(result)
		end,
		on_stderr = function(_, data)
			if not data or #data < 1 or (data[1] == "" and #data == 1) then
				return
			end

			local error_msg = table.concat(data, "\n")
			vim.schedule(function()
				vim.notify("Error formatting TypeScript error: " .. error_msg, vim.log.levels.ERROR)
			end)
			callback(nil)
		end,
		on_exit = function(_, code)
			if code ~= 0 then
				vim.schedule(function()
					vim.notify("Failed to format TypeScript error. Exit code: " .. code, vim.log.levels.ERROR)
				end)
				callback(nil)
			end
		end,
	})
	vim.fn.chansend(job_id, json_str)
	vim.fn.chanclose(job_id, "stdin")
end

return M
