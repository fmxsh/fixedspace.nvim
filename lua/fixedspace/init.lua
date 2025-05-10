local M = {}

-- Default configuration options
local default_opts = {
	{
		width = 25, -- Width of the vertical split
		buf_name = "xfixedspacex",
		winfixwidth = true,
		modifiable = true,
		buftype = "nofile",
		bufhidden = "wipe",
		swapfile = false,
		enterable = true,
		wrap = false,
	},
	{
		width = 25, -- Width of the vertical split
		buf_name = "xfixedspace2x",
		winfixwidth = true,
		modifiable = true,
		buftype = "nofile",
		bufhidden = "wipe",
		swapfile = false,
		enterable = true,
		wrap = false,
	},
}

local opts = {}

-- Track the two buffers/windows
M.buf_id = nil
M.win_id = nil
M.buf_id2 = nil
M.win_id2 = nil

-- Merge user config with defaults
function M.setup(user_opts)
	opts[1] = vim.tbl_deep_extend("force", default_opts[1], user_opts[1] or {})
	opts[2] = vim.tbl_deep_extend("force", default_opts[2], user_opts[2] or {})
end

-- Restor the specific layout with regard to if we have a split window into two in between left and right column.
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
	if #full_height_wins < 4 then
		log("Not enough full-height vertical splits to resize.")
		return
	end

	-- Get the second full-height split from the right
	local second_from_right_win = full_height_wins[#full_height_wins - 1]

	-- Resize it by moving it 20 cells to the right
	local current_width = vim.api.nvim_win_get_width(second_from_right_win)
	vim.api.nvim_win_set_width(second_from_right_win, current_width - delta)
end

local function create_one_window(index, position)
	local prev_win = vim.api.nvim_get_current_win()

	-- Choose split position
	if position == "topleft" then
		vim.cmd("topleft vsplit")
	else
		vim.cmd("botright vsplit")
	end

	-- We are now in the new window
	local win_id = vim.api.nvim_get_current_win()

	-- Create a brand-new buffer
	local scratch_buf = vim.api.nvim_create_buf(false, true)

	-- Set that buffer into this window
	vim.api.nvim_win_set_buf(win_id, scratch_buf)

	-- Rename it
	vim.api.nvim_buf_set_name(scratch_buf, opts[index].buf_name)

	-- Apply buffer settings
	vim.bo[scratch_buf].buftype = opts[index].buftype
	vim.bo[scratch_buf].bufhidden = opts[index].bufhidden
	vim.bo[scratch_buf].swapfile = opts[index].swapfile
	vim.bo[scratch_buf].modifiable = opts[index].modifiable
	vim.bo[scratch_buf].filetype = "nofile" -- Avoid Treesitter parsing errors

	-- Apply window settings
	vim.wo[win_id].number = false
	vim.wo[win_id].relativenumber = false
	vim.wo[win_id].signcolumn = "no"
	vim.wo[win_id].fillchars = "eob: "
	vim.wo[win_id].wrap = opts[index].wrap

	if opts[index].winfixwidth then
		vim.wo[win_id].winfixwidth = true
	end

	vim.api.nvim_win_set_width(win_id, opts[index].width)

	-- If not enterable, return to previous window upon entry
	if not opts[index].enterable then
		vim.api.nvim_create_autocmd("WinEnter", {
			buffer = scratch_buf,
			callback = function()
				if vim.api.nvim_win_is_valid(prev_win) then
					vim.api.nvim_set_current_win(prev_win)
				end
			end,
		})
	end

	-- Auto-delete buffer when window is closed
	vim.api.nvim_create_autocmd("WinClosed", {
		callback = function(event)
			local closed_win_id = tonumber(event.match)
			if closed_win_id == win_id then
				-- If buffer is not visible in any other window, delete it
				local still_open = false
				for _, w in ipairs(vim.api.nvim_list_wins()) do
					if vim.api.nvim_win_get_buf(w) == scratch_buf then
						still_open = true
						break
					end
				end
				if not still_open and vim.api.nvim_buf_is_valid(scratch_buf) then
					vim.api.nvim_buf_delete(scratch_buf, { force = true })
				end
			end
		end,
	})

	-- Return to the previous window
	vim.api.nvim_set_current_win(prev_win)
	return scratch_buf, win_id
end

--
-- OLD VERSION BEFORE MUL OPTS
--
--local function create_one_window(bufname, position)
--	local prev_win = vim.api.nvim_get_current_win()
--
--	-- Choose split position
--	if position == "topleft" then
--		vim.cmd("topleft vsplit")
--	else
--		vim.cmd("botright vsplit")
--	end
--
--	-- We are now in the new window
--	local win_id = vim.api.nvim_get_current_win()
--
--	-- Create a brand-new buffer
--	local scratch_buf = vim.api.nvim_create_buf(false, true)
--
--	-- Set that buffer into this window
--	vim.api.nvim_win_set_buf(win_id, scratch_buf)
--
--	-- Rename it
--	vim.api.nvim_buf_set_name(scratch_buf, bufname)
--
--	-- Apply buffer settings
--	vim.bo[scratch_buf].buftype = opts.buftype
--	vim.bo[scratch_buf].bufhidden = opts.bufhidden
--	vim.bo[scratch_buf].swapfile = opts.swapfile
--	vim.bo[scratch_buf].modifiable = opts.modifiable
--	vim.bo[scratch_buf].filetype = "nofile" -- Avoid Treesitter parsing errors
--
--	-- Apply window settings
--	vim.wo[win_id].number = false
--	vim.wo[win_id].relativenumber = false
--	vim.wo[win_id].signcolumn = "no"
--	vim.wo[win_id].fillchars = "eob: "
--
--	if opts.winfixwidth then
--		vim.wo[win_id].winfixwidth = true
--	end
--
--	vim.api.nvim_win_set_width(win_id, opts.width)
--
--	-- If not enterable, return to previous window upon entry
--	if not opts.enterable then
--		vim.api.nvim_create_autocmd("WinEnter", {
--			buffer = scratch_buf,
--			callback = function()
--				if vim.api.nvim_win_is_valid(prev_win) then
--					vim.api.nvim_set_current_win(prev_win)
--				end
--			end,
--		})
--	end
--
--	-- Auto-delete buffer when window is closed
--	vim.api.nvim_create_autocmd("WinClosed", {
--		callback = function(event)
--			local closed_win_id = tonumber(event.match)
--			if closed_win_id == win_id then
--				-- If buffer is not visible in any other window, delete it
--				local still_open = false
--				for _, w in ipairs(vim.api.nvim_list_wins()) do
--					if vim.api.nvim_win_get_buf(w) == scratch_buf then
--						still_open = true
--						break
--					end
--				end
--				if not still_open and vim.api.nvim_buf_is_valid(scratch_buf) then
--					vim.api.nvim_buf_delete(scratch_buf, { force = true })
--				end
--			end
--		end,
--	})
--
--	-- Return to the previous window
--	vim.api.nvim_set_current_win(prev_win)
--	return scratch_buf, win_id
--end

--- Both windows to right
----------------------------------------------------------------------------------
---- Helper: create one window+buffer with botright vsplit
----------------------------------------------------------------------------------
--local function create_one_window(bufname)
--	local prev_win = vim.api.nvim_get_current_win()
--
--	-- Split
--	vim.cmd("botright vsplit")
--
--	-- We are now in the new window
--	local win_id = vim.api.nvim_get_current_win()
--
--	-- (1) Create an actual new buffer
--	--     false = listed, true = scratch/unlisted, pick whichever you want
--	local scratch_buf = vim.api.nvim_create_buf(false, true)
--
--	-- (2) Set that buffer into this window
--	vim.api.nvim_win_set_buf(win_id, scratch_buf)
--
--	-- (3) Rename it
--	vim.api.nvim_buf_set_name(scratch_buf, bufname)
--
--	-- (4) Apply your standard buffer/window options
--	vim.bo[scratch_buf].buftype = opts.buftype -- "nofile"
--	vim.bo[scratch_buf].bufhidden = opts.bufhidden -- "wipe"
--	vim.bo[scratch_buf].swapfile = opts.swapfile -- false
--	vim.bo[scratch_buf].modifiable = opts.modifiable
--	-- filetype = nofile (so that treesitter won't try to parse it):
--	vim.bo[scratch_buf].filetype = "nofile"
--
--	vim.wo[win_id].number = false
--	vim.wo[win_id].relativenumber = false
--	vim.wo[win_id].signcolumn = "no"
--	vim.wo[win_id].fillchars = "eob: "
--
--	if opts.winfixwidth then
--		vim.wo[win_id].winfixwidth = true
--	end
--
--	vim.api.nvim_win_set_width(win_id, opts.width)
--
--	-- If not enterable, bounce back to prev_win on entry
--	if not opts.enterable then
--		vim.api.nvim_create_autocmd("WinEnter", {
--			buffer = scratch_buf,
--			callback = function()
--				if vim.api.nvim_win_is_valid(prev_win) then
--					vim.api.nvim_set_current_win(prev_win)
--				end
--			end,
--		})
--	end
--
--	-- Autocmd to wipe the buffer if the window is closed
--	vim.api.nvim_create_autocmd("WinClosed", {
--		callback = function(event)
--			local closed_win_id = tonumber(event.match)
--			if closed_win_id == win_id then
--				-- If buffer not visible elsewhere, delete it
--				local still_open = false
--				for _, w in ipairs(vim.api.nvim_list_wins()) do
--					if vim.api.nvim_win_get_buf(w) == scratch_buf then
--						still_open = true
--						break
--					end
--				end
--				if not still_open and vim.api.nvim_buf_is_valid(scratch_buf) then
--					vim.api.nvim_buf_delete(scratch_buf, { force = true })
--				end
--			end
--		end,
--	})
--
--	-- Jump back to the old window
--	vim.api.nvim_set_current_win(prev_win)
--	return scratch_buf, win_id
--end

--------------------------------------------------------------------------------
-- Create both scratch windows: rightmost will be buf_id, to its left buf_id2
--------------------------------------------------------------------------------
function M.create_fixedspace()
	-- If we already have something matching opts.buf_name open, skip
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local b = vim.api.nvim_win_get_buf(win)
		local n = vim.api.nvim_buf_get_name(b) or ""
		if n:find(opts[1].buf_name, 1, true) then
			-- Already open
			return
		end
	end

	-- 1) Create the "second" window first (so it ends up on the LEFT)
	--	M.buf_id2, M.win_id2 = create_one_window(opts.buf_name .. "2", "topleft")

	-- 2) Create the "first" window second (which will be on the RIGHT)
	--	M.buf_id, M.win_id = create_one_window(opts.buf_name, "botright")

	M.buf_id2, M.win_id2 = create_one_window(2, "topleft")
	M.buf_id, M.win_id = create_one_window(1, "botright")

	--- Both windows to right
	---- 1) Create the "second" window first (so it ends up on the left)
	--M.buf_id2, M.win_id2 = create_one_window(opts.buf_name .. "2")

	---- 2) Create the "first" window last (which will be the far-right)
	--M.buf_id, M.win_id = create_one_window(opts.buf_name)

	-- done!
	resize_second_from_right_split(opts[2].width)
end

function M.enable()
	-- Make sure both windows exist. If not, create them.
	local open_1, open_2 = false, false
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local b = vim.api.nvim_win_get_buf(win)
		local n = vim.api.nvim_buf_get_name(b)
		if n == opts[1].buf_name then
			open_1 = true
		elseif n == opts[2].buf_name .. "2" then
			open_2 = true
		end
	end

	if not open_1 or not open_2 then
		M.create_fixedspace()
	end
end

function M.disable()
	-- Close any open windows showing these buffers
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local b = vim.api.nvim_win_get_buf(win)
		local n = vim.api.nvim_buf_get_name(b) or ""
		-- if it matches either "xfixedspacex" or "xfixedspacex2"
		if n:find(opts[1].buf_name, 1, true) then
			vim.api.nvim_win_close(win, true)
		end

		if n:find(opts[2].buf_name, 1, true) then
			vim.api.nvim_win_close(win, true)
		end
	end

	M.buf_id = nil
	M.win_id = nil
	M.buf_id2 = nil
	M.win_id2 = nil
end

--- We do not use this function , its not updated
function M.toggle()
	-- Check if either buffer is displayed
	local is_open = false
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local b = vim.api.nvim_win_get_buf(win)
		local n = vim.api.nvim_buf_get_name(b) or ""
		if n:find(opts.buf_name, 1, true) then
			is_open = true
			break
		end
	end

	if is_open then
		M.disable()
	else
		M.enable()
	end
end

return M
