local M = {}

-- Default configuration options
local default_opts = {
	width = 25, -- Width of the vertical split
	buf_name = "xfixedspacex", -- Name of the scratch buffer
	winfixwidth = true, -- Prevent resizing the window
	modifiable = true, -- Make buffer read-only
	buftype = "nofile", -- Make it a scratch buffer
	bufhidden = "wipe", -- Auto-remove buffer when closed
	swapfile = false, -- No swap file
	enterable = true, -- Prevent entering the window
}

-- User-defined options
local opts = {}

M.buf_id = nil
M.win_id = nil

-- Setup function for user configuration
function M.setup(user_opts)
	opts = vim.tbl_deep_extend("force", default_opts, user_opts or {})
end
-- Simple functoin, wont restore complex window layout, simply makes sure if 2 windows are open, they are split in middle relatve to  the fixed space.
-- Actually not middle, but leftmost has some more space, which aligns with my workflow.
local function resize_second_from_right_split(delta)
	local wins = vim.api.nvim_list_wins()
	local full_height_wins = {}

	-- Collect all full-height vertical splits
	for _, win in ipairs(wins) do
		local win_height = vim.api.nvim_win_get_height(win)
		if win_height == vim.o.lines - vim.o.cmdheight - 1 then
			table.insert(full_height_wins, win)
		end
	end

	-- Sort windows by their column position (left to right)
	table.sort(full_height_wins, function(a, b)
		local pos_a = vim.api.nvim_win_get_position(a)[2]
		local pos_b = vim.api.nvim_win_get_position(b)[2]
		return pos_a < pos_b
	end)

	-- Ensure we have at least 2 full-height vertical splits
	log("full_height_wins: " .. vim.inspect(full_height_wins))
	if #full_height_wins < 3 then
		log("Not enough full-height vertical splits to resize.")
		return
	end

	-- Get the second full-height split from the right
	local second_from_right_win = full_height_wins[#full_height_wins - 1]

	-- Resize it by moving it 20 cells to the right
	local current_width = vim.api.nvim_win_get_width(second_from_right_win)
	vim.api.nvim_win_set_width(second_from_right_win, current_width - delta)
end
-- Create a real vertical split with a scratch buffer
function M.create_fixedspace()
	log("create_fixedspace called")
	-- Check if the buffer already exists
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		local bufname = vim.api.nvim_buf_get_name(buf)
		if vim.api.nvim_buf_is_valid(buf) and bufname:find(opts.buf_name, 1, true) then
			return buf -- ✅ Found a buffer that contains the name
		end
	end

	-- check if buffer exist by name, if fixedspace is in any buf name
	--	if vim.api.nvim_buf_get_name(0):find(opts.buf_name) then
	--		return
	--	end
	--
	-- Store current window to move cursor back later
	local current_win = vim.api.nvim_get_current_win()

	-- Open a new vertical split
	vim.cmd("vnew")

	-- Get the window ID of the newly created split
	local win_id = vim.api.nvim_get_current_win()

	-- Move the split to the rightmost position
	vim.cmd("wincmd L")

	-- Resize the split width correctly
	vim.api.nvim_win_set_width(win_id, opts.width)

	-- Get the buffer ID
	local buf = vim.api.nvim_get_current_buf()

	-- Set buffer name
	vim.api.nvim_buf_set_name(buf, opts.buf_name)

	-- Apply buffer options
	vim.bo[buf].buftype = opts.buftype
	vim.bo[buf].bufhidden = opts.bufhidden
	vim.bo[buf].swapfile = opts.swapfile
	vim.bo[buf].modifiable = opts.modifiable

	M.buf_id = buf
	M.win_id = win_id

	-- Disable line numbers
	vim.wo[win_id].number = false
	vim.wo[win_id].relativenumber = false

	-- Hide sign column
	vim.wo[win_id].signcolumn = "no"
	vim.wo[win_id].fillchars = "eob: "

	-- Prevent resizing of the window
	if opts.winfixwidth then
		vim.wo[win_id].winfixwidth = true
	end

	-- Prevent entering the window (move back immediately if entered)
	if not opts.enterable then
		vim.api.nvim_create_autocmd("WinEnter", {
			buffer = buf,
			callback = function()
				--if vim.api.nvim_get_current_win() == win_id then
				--	vim.api.nvim_set_current_win(current_win)
				--end
				-- Ensure the previous window is still valid
				if vim.api.nvim_win_is_valid(current_win) then
					vim.api.nvim_set_current_win(current_win)
				end
			end,
		})
	end

	-- Set autocmd to clean up when closed
	vim.api.nvim_create_autocmd("WinClosed", {
		callback = function(event)
			local closed_win_id = tonumber(event.match)
			-- Check if the buffer is still valid before deleting
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf):find(opts.buf_name, 1, true) then
					--	if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == opts.buf_name then
					-- Ensure the buffer is not being displayed in another window
					local buf_still_open = false
					for _, win in ipairs(vim.api.nvim_list_wins()) do
						if vim.api.nvim_win_get_buf(win) == buf then
							buf_still_open = true
							break
						end
					end
					-- If no other windows show the buffer, delete it
					if not buf_still_open then
						vim.api.nvim_buf_delete(buf, { force = true })
					end
					return
				end
			end
		end,
	})

	-- Move cursor back to the previous window
	vim.api.nvim_set_current_win(current_win)

	--vim.defer_fn(function()
	resize_second_from_right_split(40)
	--end, 1)
	return buf
end

-- Enable function to ensure the fixed space buffer is open
function M.enable()
	log("fixedspace enable")
	-- Check if a buffer named "fixedspace" already exists
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == opts.buf_name then
			-- Ensure it's displayed in a window
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				if vim.api.nvim_win_get_buf(win) == buf then
					return -- The buffer is already open in a window
				end
			end
			-- If buffer exists but not displayed, create a new window for it
			vim.cmd("vnew") -- Open a vertical split
			vim.api.nvim_set_current_buf(buf)
			vim.cmd("wincmd L") -- Move to the rightmost position
			vim.api.nvim_win_set_width(0, opts.width)
			return
		end
	end
	-- If the buffer doesn't exist, create it
	M.create_fixedspace()
end

-- Disable function to close and remove the fixed space buffer
function M.disable()
	M.buf_id = nil
	M.win_id = nil
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf):find(opts.buf_name, 1, true) then
			-- Check if it's displayed in any window and close it
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				if vim.api.nvim_win_get_buf(win) == buf then
					vim.api.nvim_win_close(win, true)
				end
			end
			-- Delete the buffer
			-- NOTE: closing the window deletes the buffer automatically, as it is a scratch buffer
			--vim.api.nvim_buf_delete(buf, { force = true })
			return
		end
	end
end

-- Toggle function to open/close the buffer
function M.toggle()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == opts.buf_name then
			vim.api.nvim_win_close(win, true)
			return
		end
	end
	M.create_fixedspace()
end

return M
