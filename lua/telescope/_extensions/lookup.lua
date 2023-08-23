local deep_extend = function(initial, partial)
	return vim.tbl_deep_extend("force", initial, partial)
end

local definition = require("lookup.definition")
local item_definition = definition.item

local fn = vim.fn
local api = vim.api
local schedule = vim.schedule

local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
	error("This plugin requires telescope.nvim as a depedency")
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local entry_display = require("telescope.pickers.entry_display")
local conf = require("telescope.config").values

local lookup = require("lookup")

local function setup(user_cfg)
	lookup.cfg = deep_extend(lookup.cfg, user_cfg)
end

local calculate_max_width_in_tbl = function(limit, tbl, key)
	local max = 0
	for _, elem in ipairs(tbl) do
		for k, v in pairs(elem) do
			if k == key and max < #v then
				max = #v
			end
		end
	end

	if max > limit then
		return limit
	else
		return max
	end
end

local function start_lookup()
	if #lookup.items == 0 then
		if lookup.cfg.strict then
			error("nothing registered to lookup")
		end

		return
	end

	local telescope_prompt_maker = function(entry)
		local row = {}
		local component_info = {}

		local desc_width =
			calculate_max_width_in_tbl(lookup.cfg.max_width[item_definition.DESC], lookup.items, item_definition.DESC)

		for _, v in ipairs(lookup.cfg.row_elements) do
			table.insert(row, entry.value[v])
			table.insert(component_info, {
				width = desc_width,
			})
		end

		local row_display_handler = entry_display.create({
			separator = lookup.cfg.separator,
			items = component_info,
		})

		return row_display_handler(row)
	end

	local current_bufnr = fn.bufnr()

	local picker_opts = {}

	local result = lookup.filter_by_buffer(lookup.items, current_bufnr, true)

	local picker = pickers.new(picker_opts, {
		prompt_title = lookup.cfg.prompt_title,
		finder = finders.new_table({
			result = result,
			entry_maker = function(entry)
				local ordinal = ""
				return {
					value = entry,
					display = telescope_prompt_maker,
					ordinal = ordinal,
				}
			end,
		}),
		sorter = conf.generic_sorter(picker_opts),
		attach_mappings = function(prompt_bufnr)
			actions.select_default:replace(function()
				actions.close(prompt_bufnr)

				local selection = action_state.get_selected_entry()
				if not selection then
					return false
				end

				local cmd = selection.value[item_definition.CMD]
				if type(cmd) == "function" then
					cmd()
				else
					cmd = api.nvim_replace_termcodes(cmd, true, false, true)
					api.nvim_feedkeys(cmd, "t", true)
				end
			end)
			return true
		end,
	})

	local env = deep_extend(getfenv(), {
		vim = { o = {}, go = {}, bo = {}, wo = {} },
	})

	local o = env.vim.o
	local go = env.vim.go
	local bo = env.vim.bo
	local wo = env.vim.wo

	schedule(function()
		vim.bo.modifiable = true
		vim.cmd("startinsert")
	end)

	picker:find()
	env.vim.o = o
	env.vim.go = go
	env.vim.bo = bo
	env.vim.wo = wo
end

return telescope.register_extension({
	setup = setup,
	exports = {
		lookup = start_lookup(),
	},
})
