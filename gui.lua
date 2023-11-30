input_title = "Plugins Thumbnail Maker"

if not reaper.ImGui_CreateContext then
	reaper.MB(
		"Missing dependency: ReaImGui extension.\nDownload it via Reapack ReaTeam extension repository.",
		"Error",
		0
	)
	return false
end

reaimgui_shim_file_path = reaper.GetResourcePath() .. "/Scripts/ReaTeam Extensions/API/imgui.lua"
if reaper.file_exists(reaimgui_shim_file_path) then
	dofile(reaimgui_shim_file_path)("0.8.6")
end

-- Set ToolBar Button State
function SetButtonState(set)
	local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
	reaper.SetToggleCommandState(sec, cmd, set or 0)
	reaper.RefreshToolbar2(sec, cmd)
end

function Exit()
	SetButtonState()
end

----------------------------------------------------------------------
-- OTHER --
----------------------------------------------------------------------
local ImGui = {}
for name, func in pairs(reaper) do
	name = name:match("^ImGui_(.+)$")
	if name then
		ImGui[name] = func
	end
end

local thispath = ({ reaper.get_action_context() })[2]:match("^.+[\\//]")
dofile(thispath .. "misc.lua")
dofile(thispath .. "plugin_icon.lua")

local datapath = thispath .. "data/"
reaper.RecursiveCreateDirectory(datapath, 0)

-- Initial parsing
local plugin_list = GetFxList()
for _, plug in ipairs(plugin_list) do
	plug.key = string.lower(plug.title)
end

local toolbars, floating_keys = ParseReaperMenu()
local fxopts = ParseReaperFxOptions()

-- defaults
local default_width, default_height = 400, 200
local default = {
	cropping = {
		do_crop = true,
		left = 10,
		right = 10,
		top = 60,
		bottom = 10,
	},
	background = {
		--istoolbar = false,
		mode = 1, -- 0: color, 1: gradient, 2: file
		width = default_width,
		height = default_height,
		file = thispath .. "background_example.png",
		color = 0x72909ac8,
		preview = nil,
		gradient = {
			mode = 1, -- 0: conic, 1: linear, 2: radial
			color1 = 0x000000ff,
			color2 = 0xffffffff,
			conic = {
				x = default_width / 2,
				y = default_height / 2,
				angle = math.pi / 4,
			},
			linear = {
				mode = 2, -- 0: horizontal, 1: mix, 2: vertical
				h = {
					x1 = 0,
					x2 = default_width,
				},
				mix = {
					x1 = 0,
					x2 = default_width,
					y1 = 0,
					y2 = default_height,
				},
				v = {
					y1 = 0,
					y2 = default_height,
				},
			},
			radial = {
				x = 0,
				y = default_height,
				radius = math.max(default_width, default_height) / 2,
			},
		},
	},
}
-- params
local plugins = {
	in_available = {},
	--available = {},
	sel_available = {},
	--selected = {},
	sel_selected = {},
}
for _ = 1, #plugin_list do
	plugins.in_available[#plugins.in_available + 1] = true

	--plugins.available[#plugins.available + 1] = true
	plugins.sel_available[#plugins.sel_available + 1] = false

	--plugins.selected[#plugins.selected + 1] = false
	plugins.sel_selected[#plugins.sel_selected + 1] = false
end

local params = {}
params.filter_available = ""
params.filter_selected = ""

params.delay_s = 0.5
params.cropping = deepcopy(default.cropping)

params.raw = {
	do_raw = false,
	destination = thispath .. "raw",
	fname_prefix = "",
	fname_suffix = "",
	preview = {
		bitmap = nil,
		path = nil,
	},
}

params.thumbnail = {
	do_thumbnail = true,
	destination = thispath .. "thumbnails",
	background = deepcopy(default.background),
	fname_prefix = "thumb_",
	fname_suffix = "",
	preview = {
		bitmap = nil,
		path = nil,
	},
}
params.thumbnail.background.preview_name = "background_icon.png"

params.toolbar_thumbnail = {
	do_thumbnail = false,
	default_destination = true,
	destination = thispath .. "toolbar_thumbnails",
	background = deepcopy(default.background),
	fname_prefix = "tb_thumb_",
	fname_suffix = "",
	color_hover = 0x349F3488,
	color_click = 0x9A0E0E88,
	preview = {
		real_mode = true,
		bitmap = nil,
		path = nil,
		mousestate = 0,
	},
}
params.toolbar_thumbnail.background.preview_name = "background_toolbar_icon.png"
--params.toolbar_thumbnail.background.istoolbar = true

local init_toolbar = 1
for i = 1, 32 do
	if floating_keys[i] == nil then
		init_toolbar = i
		break
	end
end
local items_tb = {}
local tb_titles = {}
for i = 1, 32 do
	local default_title = string.format("Toolbar %d", i)
	if
		floating_keys[i] ~= nil
		and toolbars[floating_keys[i]].title ~= nil
		and toolbars[floating_keys[i]].title ~= default_title
	then
		tb_titles[#tb_titles + 1] = toolbars[floating_keys[i]].title
		items_tb[#items_tb + 1] = string.format("Floating toolbar %d (%s)", i, tb_titles[#tb_titles])
	else
		tb_titles[#tb_titles + 1] = default_title
		items_tb[#items_tb + 1] = string.format("Floating toolbar %d", i)
	end
end
params.toolbar_maker = {
	do_toolbar = false,
	toolbar = init_toolbar,
	items = items_tb,
	overwrite = false,
	title = tb_titles[init_toolbar],
}

local path_toolbar_icons = reaper.GetResourcePath() .. "/Data/toolbar_icons/"

---
function MoveToSelectedArea()
	for i, sel in ipairs(plugins.sel_available) do
		if sel then
			plugins.sel_available[i] = false
			plugins.in_available[i] = false
			plugins.sel_selected[i] = true
		end
	end
end

function MoveToAvailableArea()
	for i, sel in ipairs(plugins.sel_selected) do
		if sel then
			plugins.sel_available[i] = true
			plugins.in_available[i] = true
			plugins.sel_selected[i] = false
		end
	end
end

function SelectAll(t, filter)
	if filter == "" then
		for i = 1, #t do
			t[i] = true
		end
	else
		for i = 1, #t do
			t[i] = t[i] or string.match(plugin_list[i].key, filter) ~= nil
		end
	end
end

function UnselectAll(t, filter)
	if filter == "" then
		for i = 1, #t do
			t[i] = false
		end
	else
		for i = 1, #t do
			t[i] = t[i] and string.match(plugin_list[i].key, filter) == nil
		end
	end
end

function SelectablesPlugins(t, filter, available)
	for i, sel in ipairs(t) do
		local skipit = filter ~= "" and not string.match(plugin_list[i].key, filter)
		if
			not skipit
			and plugins.in_available[i] == available
			and reaper.ImGui_Selectable(ctx, ("%d: %s"):format(i, plugin_list[i].title), sel)
		then
			if not reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) then -- Clear selection when CTRL is not heldk
				for j = 1, #t do
					t[j] = false
				end
			end
			t[i] = not sel
		end
	end
end

function plugin_list_view()
	local size = { 100, 30 }
	local width, height = reaper.ImGui_GetContentRegionAvail(ctx)
	local listSize = 4 * size[2] + height / 4

	local filter = string.lower(params.filter_available)

	reaper.ImGui_SeparatorText(ctx, "Plugin list")

	reaper.ImGui_BeginDisabled(ctx, not any(plugins.sel_available))
	if reaper.ImGui_Button(ctx, "Select", size[1], size[2]) then
		MOVE_TO_SELECTED_AREA = true
	end
	reaper.ImGui_EndDisabled(ctx)
	if ImGui.IsItemHovered(ctx) then
		ImGui.SetTooltip(ctx, "Move plugins to the selected area")
	end

	reaper.ImGui_SameLine(ctx)

	-- select all visible
	if reaper.ImGui_Button(ctx, "All", size[1], size[2]) then
		SELECT_ALL_AVAILABLE = true
	end
	if ImGui.IsItemHovered(ctx) then
		ImGui.SetTooltip(ctx, "Select all visible plugins in the list")
	end

	reaper.ImGui_SameLine(ctx)

	-- deselect all visible
	if reaper.ImGui_Button(ctx, "None", size[1], size[2]) then
		UNSELECT_ALL_AVAILABLE = true
	end
	if ImGui.IsItemHovered(ctx) then
		ImGui.SetTooltip(ctx, "Unselect all visible plugins in the list")
	end

	_, params.filter_available = reaper.ImGui_InputText(
		ctx,
		"Filter ",
		params.filter_available,
		reaper.ImGui_InputTextFlags_EscapeClearsAll() | reaper.ImGui_InputTextFlags_AutoSelectAll()
	)

	if reaper.ImGui_BeginChild(ctx, "ChildAvailablePluginList", 0, listSize, true) then
		filter = string.lower(params.filter_available)
		SelectablesPlugins(plugins.sel_available, filter, true)
		reaper.ImGui_EndChild(ctx)
	end
	local navailable = countTrue(plugins.in_available)
	reaper.ImGui_Text(ctx, string.format("%d plugins", navailable))

	reaper.ImGui_SeparatorText(ctx, "Selection")

	reaper.ImGui_BeginDisabled(ctx, not any(plugins.sel_selected))
	if reaper.ImGui_Button(ctx, "Unselect", size[1], size[2]) then
		MOVE_TO_AVAILABLE_AREA = true
	end

	reaper.ImGui_SameLine(ctx)

	-- select all visible
	if reaper.ImGui_Button(ctx, "All ", size[1], size[2]) then
		SELECT_ALL_SELECTED = true
	end
	if ImGui.IsItemHovered(ctx) then
		ImGui.SetTooltip(ctx, "Select all visible plugins")
	end

	reaper.ImGui_SameLine(ctx)

	-- deselect all visible
	if reaper.ImGui_Button(ctx, "None ", size[1], size[2]) then
		UNSELECT_ALL_SELECTED = true
	end
	if ImGui.IsItemHovered(ctx) then
		ImGui.SetTooltip(ctx, "Unselect all visible plugins")
	end

	_, params.filter_selected = reaper.ImGui_InputText(
		ctx,
		"Filter",
		params.filter_selected,
		reaper.ImGui_InputTextFlags_EscapeClearsAll() | reaper.ImGui_InputTextFlags_AutoSelectAll()
	)

	if reaper.ImGui_BeginChild(ctx, "ChildSelectedPluginList", 0, listSize, true) then
		filter = params.filter_selected
		SelectablesPlugins(plugins.sel_selected, filter, false)
		reaper.ImGui_EndChild(ctx)
	end
	reaper.ImGui_EndDisabled(ctx)
	local nselected = #plugins.in_available - navailable
	reaper.ImGui_Text(ctx, string.format("%d plugins selected", nselected))
end

function GenerateBackground(p)
	if p.mode == 0 then
		return CreateColorImage(RGBA2ARGB(p.color), p.width, p.height)
	elseif p.mode == 1 then
		local bmp = reaper.JS_LICE_CreateBitmap(true, p.width, p.height)
		local g = p.gradient
		local col1, col2 = RGBA2ARGB(g.color1), RGBA2ARGB(g.color2)
		if g.mode == 0 then -- conic
			return ConicGradient(bmp, g.conic.x, g.conic.y, g.conic.angle, col1, col2)
		elseif g.mode == 1 then -- linear
			local l = g.linear
			if l.mode == 0 then -- Horizontal
				return LinearHGradient(bmp, l.h.x1, l.h.x2, col1, col2)
			elseif l.mode == 2 then -- Vertical
				return LinearVGradient(bmp, l.v.y1, l.v.y2, col1, col2)
			else
				return LinearGradient(bmp, l.mix.x1, l.mix.x2, l.mix.y1, l.mix.y2, col1, col2)
			end
		else -- radial
			return RadialGradient(bmp, g.radial.x, g.radial.y, g.radial.radius, col1, col2)
		end
	else
		local fname = p.file
		if not reaper.file_exists(fname) then
			reaper.MB("No such file: " .. fname)
			return
		end

		local ext = fname:sub(-4)
		if ext == ".png" then
			return reaper.JS_LICE_LoadPNG(fname)
		elseif ext == ".jpg" then
			return reaper.JS_LICE_LoadJPG(fname)
		else
			reaper.MB("Not a valid image file (jpg/png): " .. fname)
		end
	end
end

function ThumbnailPath(dir, prefix, fxname, suffix)
	return string.format("%s/%s%s%s.png", dir, prefix, fxname, suffix)
end

function FileController(p, title)
	reaper.ImGui_SeparatorText(ctx, "Files parameters")
	if ImGui.IsItemHovered(ctx) then
		ImGui.SetTooltip(ctx, "Filenames and destination")
	end

	if reaper.ImGui_BeginChild(ctx, title, 0, 70, true) then
		local x, y = reaper.ImGui_GetContentRegionAvail(ctx)
		reaper.ImGui_PushItemWidth(ctx, x / 3)

		_, p.fname_prefix = ImGui.InputText(ctx, "Prefix", p.fname_prefix)
		if ImGui.IsItemHovered(ctx) then
			ImGui.SetTooltip(ctx, "Filename(s) prefix")
		end

		reaper.ImGui_SameLine(ctx)

		_, p.fname_suffix = ImGui.InputText(ctx, "Suffix", p.fname_suffix)
		if ImGui.IsItemHovered(ctx) then
			ImGui.SetTooltip(ctx, "Filename(s) suffix (without extension)")
		end

		if reaper.ImGui_Button(ctx, "Destination...", 100, 30) then
			rv, folder = reaper.JS_Dialog_BrowseForFolder(title, p.destination)
			if rv ~= 0 then
				p.destination = folder
			end
		end
		if ImGui.IsItemHovered(ctx) then
			ImGui.SetTooltip(ctx, "Choose destination folder")
		end

		reaper.ImGui_EndChild(ctx)
	end
end

function CroppingControl()
	reaper.ImGui_SeparatorText(ctx, "Cropping")
	if ImGui.IsItemHovered(ctx) then
		ImGui.SetTooltip(ctx, "Screenshot cropping to remove window borders")
	end

	if reaper.ImGui_BeginChild(ctx, "ChildCropping", 0, 100) then
		local pc = params.cropping

		_, pc.do_crop = reaper.ImGui_Checkbox(ctx, "Crop window borders", pc.do_crop)

		reaper.ImGui_BeginDisabled(ctx, not pc.do_crop)

		_, pc.top, pc.bottom = reaper.ImGui_DragInt2(ctx, "top/bottom", pc.top, pc.bottom, 1, 0, 100)
		_, pc.left, pc.right = reaper.ImGui_DragInt2(ctx, "left/right", pc.left, pc.right, 1, 0, 50)
		local sizeX, sizeY = 100, 30
		if reaper.ImGui_Button(ctx, "Reset", sizeX, sizeY) then
			params.cropping = deepcopy(default.cropping)
		end
		if ImGui.IsItemHovered(ctx) then
			ImGui.SetTooltip(ctx, "Reset cropping parameters to default values")
		end

		reaper.ImGui_EndDisabled(ctx)

		reaper.ImGui_EndChild(ctx)
	end
end

function PopupBackgroundPreview(p)
	if reaper.ImGui_BeginPopup(ctx, p.preview_name) then
		local bitmap = p.preview
		local w, h = reaper.ImGui_Image_GetSize(bitmap)
		reaper.ImGui_Image(ctx, bitmap, w, h)
		if reaper.ImGui_Button(ctx, "Close") then
			reaper.ImGui_CloseCurrentPopup(ctx)
		end
		reaper.ImGui_EndPopup(ctx)
	end
end

function BackgroundControl(p, istoolbar)
	reaper.ImGui_SeparatorText(ctx, "Background")
	local previewExportButtons = function()
		local size = { 100, 30 }
		local x, _ = reaper.ImGui_GetContentRegionAvail(ctx)
		local posX = (x - size[1]) / 3
		local posY = reaper.ImGui_GetCursorPosY(ctx) --+ size[2]
		reaper.ImGui_SetCursorPos(ctx, posX, posY)
		if reaper.ImGui_Button(ctx, "Preview", size[1], size[2]) then
			if istoolbar then
				if deepeq(p, TOOLBAR_BACKGROUND_PARAMS) then
					BACKGROUND_READY = true
				else
					TOOLBAR_BACKGROUND_PARAMS = deepcopy(p)
					GENERATE_TOOLBAR_BACKGROUND = true
				end
			else
				if deepeq(p, ICON_BACKGROUND_PARAMS) then
					BACKGROUND_READY = true
				else
					ICON_BACKGROUND_PARAMS = deepcopy(p)
					GENERATE_ICON_BACKGROUND = true
					-- msg("SET GENERATE_ICON_BACKGROUND = true")
				end
			end
		end
		if ImGui.IsItemHovered(ctx) then
			ImGui.SetTooltip(ctx, "Open background preview popup")
		end

		if BACKGROUND_READY and ImGui.ValidatePtr(p.preview, "ImGui_Image*") then
			BACKGROUND_READY = false
			reaper.ImGui_OpenPopup(ctx, p.preview_name)
		end
		PopupBackgroundPreview(p)

		reaper.ImGui_SameLine(ctx)
		if reaper.ImGui_Button(ctx, "Export", size[1], size[2]) then
			if istoolbar then
				EXPORT_BACKGROUND_TOOLBAR = true
			else
				EXPORT_BACKGROUND_ICON = true
			end
		end
		if ImGui.IsItemHovered(ctx) then
			ImGui.SetTooltip(ctx, "Export background to file for reuse")
		end
	end

	if reaper.ImGui_BeginChild(ctx, p.preview_name, 0, 205, true) then
		reaper.ImGui_PushItemWidth(ctx, 150)

		local combo_items = "Color\0Gradient\0Image\0"
		_, p.mode = ImGui.Combo(ctx, "Mode", p.mode, combo_items)
		if ImGui.IsItemHovered(ctx) then
			ImGui.SetTooltip(ctx, "Select background mode (color/gradient/image)")
		end

		reaper.ImGui_PopItemWidth(ctx)

		-- Color
		if p.mode == 0 then
			_, p.width, p.height = reaper.ImGui_DragInt2(ctx, "Width x Height", p.width, p.height, 1, 25, 2000)
			if ImGui.IsItemHovered(ctx) then
				ImGui.SetTooltip(ctx, "Background dimension, also icon dimension")
			end

			_, p.color = ImGui.ColorEdit4(ctx, "Color", p.color, ImGui.ColorEditFlags_NoInputs())
			-- Gradient
		elseif p.mode == 1 then
			local g = p.gradient
			reaper.ImGui_SameLine(ctx)
			reaper.ImGui_PushItemWidth(ctx, 100)
			local combo_items = "Conic\0Linear\0Radial\0"
			_, g.mode = ImGui.Combo(ctx, "Type", g.mode, combo_items)
			reaper.ImGui_PopItemWidth(ctx)

			_, g.color1 = ImGui.ColorEdit4(ctx, "Color 1", g.color1, ImGui.ColorEditFlags_NoInputs())
			reaper.ImGui_SameLine(ctx)
			_, g.color2 = ImGui.ColorEdit4(ctx, "Color 2", g.color2, ImGui.ColorEditFlags_NoInputs())

			_, p.width, p.height = reaper.ImGui_DragInt2(ctx, "width x height", p.width, p.height, 25, 2000)
			-- Conic
			if g.mode == 0 then
				if reaper.ImGui_BeginChild(ctx, "ChildConic", 0, 85, true) then
					local c = g.conic
					if c.x == nil then
						c.x = p.width / 2
						c.y = p.height / 2
					end
					reaper.ImGui_SeparatorText(ctx, "Conic gradient")
					reaper.ImGui_PushItemWidth(ctx, 100)
					_, c.x, c.y = reaper.ImGui_DragInt2(ctx, "x, y", c.x, c.y, 1) --, 0, p.width - 1)
					reaper.ImGui_SameLine(ctx)
					_, c.angle = reaper.ImGui_DragDouble(ctx, "angle (rad)", c.angle, 1, 0, math.pi)
					reaper.ImGui_PopItemWidth(ctx)
					reaper.ImGui_EndChild(ctx)
				end
			-- linear
			elseif g.mode == 1 then
				reaper.ImGui_SeparatorText(ctx, "Linear gradient")
				if reaper.ImGui_BeginChild(ctx, "ChildLinear", 0, 60, true) then
					local l = g.linear
					reaper.ImGui_PushItemWidth(ctx, 100)
					local linear_items = "Horizontal\0Mix\0Vertical\0"
					_, l.mode = ImGui.Combo(ctx, "Orientation", l.mode, linear_items)
					reaper.ImGui_PopItemWidth(ctx)
					-- horizontal
					if l.mode == 0 then
						if l.h.x1 == nil then
							l.h.x1, l.h.x2 = 0, p.width - 1
						end
						_, l.h.x1, l.h.x2 = reaper.ImGui_DragInt2(ctx, "X start, end", l.h.x1, l.h.x2, 1) --, 0, p.width - 1)
					-- mix
					elseif l.mode == 1 then
						if l.mix.x1 == nil then
							l.mix.x1, l.mix.x2 = 0, p.width - 1
							l.v.x1, l.v.x2 = 0, p.height - 1
						end
						_, l.mix.x1, l.mix.x2 = reaper.ImGui_DragInt2(ctx, "X start, end", l.mix.x1, l.mix.x2, 1) --, 0, p.width - 1)
						reaper.ImGui_SameLine(ctx)
						_, l.mix.y1, l.mix.y2 = reaper.ImGui_DragInt2(ctx, "Y start, end", l.mix.y1, l.mix.y2, 1) --, 0, p.height - 1)
					-- vertical
					else
						if l.v.y1 == nil then
							l.v.y1, l.v.y2 = 0, p.height - 1
						end
						_, l.v.y1, l.v.y2 = reaper.ImGui_DragInt2(ctx, "Y start, end", l.v.y1, l.v.y2, 1) --, 0, p.height - 1)
					end
					reaper.ImGui_EndChild(ctx)
				end
			-- radial
			else
				if reaper.ImGui_BeginChild(ctx, "ChildRadial", 0, 85, true) then
					reaper.ImGui_SeparatorText(ctx, "Radial gradient")
					local r = g.radial
					if r.x == nil then
						r.x = p.width / 2
						r.y = p.height / 2
						r.radius = math.min(p.height, p.width) / 2
					end
					reaper.ImGui_PushItemWidth(ctx, 100)
					_, r.x, r.y = reaper.ImGui_DragInt2(ctx, "x, y", r.x, r.y, 1) --, 0, p.width - 1)
					_, r.radius = reaper.ImGui_DragInt(ctx, "radius", r.radius, 1) -- , 0, rad_max)
					reaper.ImGui_PopItemWidth(ctx)
					reaper.ImGui_EndChild(ctx)
				end
			end

			-- image file
		else
			reaper.ImGui_BeginDisabled(ctx, true)
			reaper.ImGui_Text(ctx, p.file)
			reaper.ImGui_EndDisabled(ctx)

			local size = { 100, 30 }
			local x, y = reaper.ImGui_GetContentRegionAvail(ctx)
			local posX = (x - size[1]) * 0.5
			local posY = reaper.ImGui_GetCursorPosY(ctx) --+ size[2]
			reaper.ImGui_SetCursorPos(ctx, posX, posY)

			if reaper.ImGui_Button(ctx, "File", size[1], size[2]) then
				local rv, file = reaper.GetUserFileNameForRead("", "Image", ".png")
				if rv ~= 0 then
					p.file = file
				end
			end
			if ImGui.IsItemHovered(ctx) then
				ImGui.SetTooltip(ctx, "Choose background location")
			end
		end

		previewExportButtons()
		reaper.ImGui_EndChild(ctx)
	end
end

function OriginalImageControl()
	_, params.raw.do_raw = reaper.ImGui_Checkbox(ctx, "Original image", params.raw.do_raw)
	reaper.ImGui_SameLine(ctx)
	reaper.ImGui_BeginDisabled(ctx, true)
	reaper.ImGui_Text(ctx, params.raw.destination)
	reaper.ImGui_EndDisabled(ctx)

	reaper.ImGui_BeginDisabled(ctx, not params.raw.do_raw)
	FileController(params.raw, "Original image destination")
	reaper.ImGui_EndDisabled(ctx)
end

function IconControl()
	local p = params.thumbnail
	_, p.do_thumbnail = reaper.ImGui_Checkbox(ctx, "Normal icon", p.do_thumbnail)
	reaper.ImGui_SameLine(ctx)
	reaper.ImGui_BeginDisabled(ctx, true)
	reaper.ImGui_Text(ctx, p.destination)
	reaper.ImGui_EndDisabled(ctx)
	reaper.ImGui_BeginDisabled(ctx, not p.do_thumbnail)
	FileController(p, "Thumbnail destination")
	BackgroundControl(p.background, false)
	reaper.ImGui_EndDisabled(ctx)
end

function ToolbarMakerControl()
	local p = params.toolbar_maker
	_, p.do_toolbar = reaper.ImGui_Checkbox(ctx, "Create toolbar", p.do_toolbar)
	reaper.ImGui_BeginDisabled(ctx, not p.do_toolbar)
	local preview_value = items_tb[p.toolbar]
	if ImGui.BeginCombo(ctx, "Toolbar", preview_value) then
		for i, v in ipairs(items_tb) do
			local is_selected = p.toolbar == i
			if ImGui.Selectable(ctx, items_tb[i], is_selected) then
				p.toolbar = i
			end

			if is_selected then
				ImGui.SetItemDefaultFocus(ctx)
			end
		end
		ImGui.EndCombo(ctx)
	end
	if floating_keys[p.toolbar] ~= nil then
		reaper.ImGui_SameLine(ctx)
		_, p.overwrite = reaper.ImGui_Checkbox(ctx, "Overwrite", p.overwrite)
	end
	_, p.title = ImGui.InputText(ctx, "Title", p.title)
	reaper.ImGui_EndDisabled(ctx)
end

function ToolbarIconControl()
	local p = params.toolbar_thumbnail
	reaper.ImGui_SeparatorText(ctx, "Toolbar icon")
	_, p.do_thumbnail = reaper.ImGui_Checkbox(ctx, "Toolbar icon", p.do_thumbnail)
	reaper.ImGui_SameLine(ctx)
	reaper.ImGui_BeginDisabled(ctx, true)
	reaper.ImGui_Text(ctx, p.destination)
	reaper.ImGui_EndDisabled(ctx)
	reaper.ImGui_BeginDisabled(ctx, not p.do_thumbnail)
	FileController(p, "Toolbar icons folder")
	BackgroundControl(p.background, true)

	reaper.ImGui_SeparatorText(ctx, "Overlays")
	if reaper.ImGui_BeginChild(ctx, "ChildOverlay", 0, 40, true) then
		local x, y = reaper.ImGui_GetContentRegionAvail(ctx)
		local w = 50
		reaper.ImGui_SetCursorPos(ctx, w, y / 2)

		_, p.color_hover = ImGui.ColorEdit4(ctx, "Hover overlay", p.color_hover, ImGui.ColorEditFlags_NoInputs())
		reaper.ImGui_SameLine(ctx)

		reaper.ImGui_SetCursorPos(ctx, x / 2 + w, y / 2)

		_, p.color_click = ImGui.ColorEdit4(ctx, "Click overlay", p.color_click, ImGui.ColorEditFlags_NoInputs())
		reaper.ImGui_EndChild(ctx)
	end
	reaper.ImGui_EndDisabled(ctx)
end

function PreviewImageControl(title, p)
	local disabled = not ImGui.ValidatePtr(p.bitmap, "ImGui_Image*")
	reaper.ImGui_BeginDisabled(ctx, disabled)
	if reaper.ImGui_Button(ctx, title, 100, 30) then
		reaper.ImGui_OpenPopup(ctx, title)
	end
	reaper.ImGui_EndDisabled(ctx)

	if reaper.ImGui_BeginPopup(ctx, title) then
		local w, h = reaper.ImGui_Image_GetSize(p.bitmap)
		reaper.ImGui_Image(ctx, p.bitmap, w, h)
		reaper.ImGui_EndPopup(ctx)
	end
end

function PreviewToolbarIconControl(title, p)
	local disabled = not ImGui.ValidatePtr(p.bitmap, "ImGui_Image*")
	reaper.ImGui_BeginDisabled(ctx, disabled)
	if reaper.ImGui_Button(ctx, title, 100, 30) then
		reaper.ImGui_OpenPopup(ctx, title)
	end
	reaper.ImGui_SameLine(ctx)
	_, p.real_mode = reaper.ImGui_Checkbox(ctx, "Toolbar mode", p.real_mode)
	reaper.ImGui_EndDisabled(ctx)

	if reaper.ImGui_BeginPopup(ctx, title) then
		local w, h = reaper.ImGui_Image_GetSize(p.bitmap)
		if p.real_mode then -- "realistic" toolbar thumbnail preview
			if p.mousestate == 0 then
				reaper.ImGui_Image(ctx, p.bitmap, w / 3, h, 0, 0, 1 / 3)
			elseif p.mousestate == 1 then
				reaper.ImGui_Image(ctx, p.bitmap, w / 3, h, 1 / 3, 0, 2 / 3)
			else
				reaper.ImGui_Image(ctx, p.bitmap, w / 3, h, 2 / 3, 0, 1)
			end
			p.mousestate = 0
			if reaper.ImGui_IsItemHovered(ctx) then
				p.mousestate = 1
			end
			if reaper.ImGui_IsItemClicked(ctx) then
				p.mousestate = 2
			end
		else -- full image preview
			reaper.ImGui_Image(ctx, p.bitmap, w, h)
		end
		reaper.ImGui_EndPopup(ctx)
	end
end

function ScreenshotParameters()
	_, params.delay_s = ImGui.SliderDouble(ctx, "Delay (s)", params.delay_s, 0.001, 3)
	if ImGui.IsItemHovered(ctx) then
		ImGui.SetTooltip(ctx, "Delay between loading the FX and taking the screenshot")
	end
	CroppingControl()
end

function ControllerPanel()
	local size = { 100, 30 }
	local x, y = reaper.ImGui_GetContentRegionAvail(ctx)
	local posX = (x - size[1]) * 0.5
	local posY = reaper.ImGui_GetCursorPosY(ctx) --+ size[2]
	reaper.ImGui_SetCursorPos(ctx, posX, posY)

	reaper.ImGui_BeginDisabled(
		ctx,
		not (params.raw.do_raw or params.thumbnail.do_thumbnail or params.toolbar_thumbnail.do_thumbnail)
	)
	if reaper.ImGui_Button(ctx, "Screenshot", size[1], size[2]) then
		START_SCREENSHOT = true
	end
	reaper.ImGui_EndDisabled(ctx)

	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(), 5.0)
	reaper.ImGui_SeparatorText(ctx, "Screenshot parameters")
	if ImGui.BeginChild(ctx, "ChildCropping", 0, 165, true) then
		ScreenshotParameters()
		reaper.ImGui_EndChild(ctx)
	end
	reaper.ImGui_SeparatorText(ctx, "Previews")
	if reaper.ImGui_BeginChild(ctx, "ChildPreview", 0, 50, true) then
		PreviewImageControl("Original", params.raw.preview)
		reaper.ImGui_SameLine(ctx)
		PreviewImageControl("Normal icon", params.thumbnail.preview)
		reaper.ImGui_SameLine(ctx)
		PreviewToolbarIconControl("Toolbar icon", params.toolbar_thumbnail.preview)
		reaper.ImGui_EndChild(ctx)
	end

	-- if reaper.ImGui_CollapsingHeader(ctx, "Image exports") then
	reaper.ImGui_SeparatorText(ctx, "Exports")

	if reaper.ImGui_CollapsingHeader(ctx, "Original image export") then
		-- if reaper.ImGui_TreeNode(ctx, "Original image export") then
		if ImGui.BeginChild(ctx, "ChildOriginal", 0, 135, true) then
			OriginalImageControl()
			reaper.ImGui_EndChild(ctx)
		end
		-- reaper.ImGui_TreePop(ctx)
	end

	if reaper.ImGui_CollapsingHeader(ctx, "Simple icon export") then
		-- if reaper.ImGui_TreeNode(ctx, "Simple icon export") then
		if ImGui.BeginChild(ctx, "ChildNormal", 0, 365, true) then
			IconControl()
			reaper.ImGui_EndChild(ctx)
		end
		-- reaper.ImGui_TreePop(ctx)
	end
	-- end
	if reaper.ImGui_CollapsingHeader(ctx, "Toolbar icon export") then
		-- if reaper.ImGui_TreeNode(ctx, "Toolbar icon export") then
		if ImGui.BeginChild(ctx, "ChilToolbarIcon", 0, 455, true) then
			ToolbarIconControl()
			reaper.ImGui_EndChild(ctx)
		end
		-- reaper.ImGui_TreePop(ctx)
	end
	-- end
	-- end
	reaper.ImGui_PopStyleVar(ctx)
end

function ExportBackground(p, path)
	local background = GenerateBackground(p)
	reaper.JS_LICE_WritePNG(path, background, false)
	reaper.JS_LICE_DestroyBitmap(background)
end

function DialogExportBackground(p)
	local rv, path =
		reaper.JS_Dialog_BrowseForSaveFile("Save background", thispath, "background.png", "Image (PNG)\0*.png\0\0")
	if rv ~= 0 then
		ExportBackground(p, path)
		p.preview = path
	end
end

function CreateToolbar()
	-- Create toolbar
	local tbm = params.toolbar_maker
	local toolbar = {
		items = {},
		icons = {},
	}
	if floating_keys[tbm.toolbar] ~= nil and not tbm.overwrite then
		toolbar = toolbars[floating_keys[tbm.toolbar]]
	end
	if tbm.title == "" then
		toolbar.title = tb_titles[tbm.toolbar]
	else
		toolbar.title = tbm.title
	end
	local max_fxopts_id = MaxFxOptionsId(fxopts)
	local fxopts_needs_overwrite = false
	local item_exists = function(action_id)
		local res = nil
		for i, item in ipairs(toolbar.items) do
			if item.action_id == action_id then
				res = i
				break
			end
		end
		return res
	end
	for _, fx in ipairs(SELECTED_PLUGS) do
		local item = {
			action_id = nil,
			action_name = string.format("Insert FX: %s", fx.title),
		}
		if fxopts[fx.fname] == nil then
			fxopts_needs_overwrite = true
			local action_id = FXNameToActionID(fx.fname)
			fxopts[fx.fname] = {
				id = max_fxopts_id,
				action_id = action_id,
			}
			item.action_id = action_id
			max_fxopts_id = max_fxopts_id + 1
		else
			item.action_id = fxopts[fx.fname].action_id
		end
		local idx = item_exists(item.action_id)
		if idx == nil then
			toolbar.items[#toolbar.items + 1] = item
			idx = #toolbar.items
		else
			toolbar.items[idx] = item
		end
		-- icons are 0 indexed, string index is for allowing text icons
		local tt = params.toolbar_thumbnail
		toolbar.icons[tostring(idx - 1)] = ThumbnailPath(path_toolbar_icons, tt.fname_prefix, fx.title, tt.fname_suffix)
	end
	local section = "Floating toolbar " .. tonumber(tbm.toolbar)
	toolbars[section] = toolbar
	if fxopts_needs_overwrite then
		OverwriteReaperFxOptions(fxopts)
	end
	OverwriteReaperMenu(toolbars)
end

function GetProcessingFunction()
	return function(screenshot, fxname)
		local cropped = CreateCrop(screenshot, P.cropping.left, P.cropping.right, P.cropping.top, P.cropping.bottom)
		if P.raw.do_raw then
			local img_path = ThumbnailPath(P.raw.destination, "", fxname, "")
			reaper.JS_LICE_WritePNG(img_path, cropped, false)
			RAW_PATH = img_path
		end

		-- Thumbnail
		if P.thumbnail.do_thumbnail then
			local p = P.thumbnail
			local background = CreateCopy(T_BACKGROUND)
			ScaledOverlay(background, cropped)

			local img_path = ThumbnailPath(p.destination, p.fname_prefix, fxname, p.fname_suffix)
			reaper.JS_LICE_WritePNG(img_path, background, false)

			reaper.JS_LICE_DestroyBitmap(background)
			T_PATH = img_path
		end

		-- Toolbar thumbnail
		if P.toolbar_thumbnail.do_thumbnail then
			local p = P.toolbar_thumbnail
			local background = CreateCopy(TBT_BACKGROUND)

			ScaledOverlay(background, cropped)
			local tb_thumbnail = CreateToolbarThumbnail(background, RGBA2ARGB(p.color_hover), RGBA2ARGB(p.color_click))

			local img_path = ThumbnailPath(p.destination, p.fname_prefix, fxname, p.fname_suffix)

			reaper.JS_LICE_WritePNG(img_path, tb_thumbnail, false)

			reaper.JS_LICE_DestroyBitmap(tb_thumbnail)
			reaper.JS_LICE_DestroyBitmap(background)
			TBT_PATH = img_path
		end
	end
end

function Iteration()
	WAITING = false
	INDEX = INDEX + 1
end

function Ending()
	WAITING = false
	-- create toolbar when all icons have created to prevent issues after potential bugs/interruptions
	if P.toolbar_maker.do_toolbar then
		CreateToolbar()
	end
	-- resources deallocation
	reaper.DeleteTrack(TRACK)
	if P.thumbnail.do_thumbnail then
		reaper.JS_LICE_DestroyBitmap(T_BACKGROUND)
	end
	if P.toolbar_thumbnail.do_thumbnail then
		reaper.JS_LICE_DestroyBitmap(TBT_BACKGROUND)
	end

	-- Setting up previews
	if P.raw.do_raw then
		local p = params.raw.preview
		if ImGui.ValidatePtr(p.bitmap, "ImGui_Image*") then
			reaper.ImGui_Detach(ctx, p.bitmap)
		end
		p.bitmap = reaper.ImGui_CreateImage(RAW_PATH)
		reaper.ImGui_Attach(ctx, p.bitmap)
	end
	if P.thumbnail.do_thumbnail then
		local p = params.thumbnail.preview
		if ImGui.ValidatePtr(p.bitmap, "ImGui_Image*") then
			reaper.ImGui_Detach(ctx, p.bitmap)
		end
		p.bitmap = reaper.ImGui_CreateImage(T_PATH)
		reaper.ImGui_Attach(ctx, p.bitmap)
	end
	if P.toolbar_thumbnail.do_thumbnail then
		local p = params.toolbar_thumbnail.preview
		if ImGui.ValidatePtr(p.bitmap, "ImGui_Image*") then
			reaper.ImGui_Detach(ctx, p.bitmap)
		end
		p.bitmap = reaper.ImGui_CreateImage(TBT_PATH)
		reaper.ImGui_Attach(ctx, p.bitmap)
	end
end

WAITING = false

----------------------------------------------------------------------
-- RUN --
----------------------------------------------------------------------
function Main()
	--------------------
	-- YOUR CODE HERE --
	--------------------

	-- UI
	ImGui.WindowFlags_HorizontalScrollbar()
	if
		ImGui.BeginChild(
			ctx,
			"ChildL",
			ImGui.GetContentRegionAvail(ctx) * 0.5,
			ImGui.GetWindowHeight(ctx) --[[ 260 ]],
			false
		)
	then
		plugin_list_view()
		ImGui.EndChild(ctx)
	end
	ImGui.SameLine(ctx)
	if ImGui.BeginChild(ctx, "ChildR", ImGui.GetContentRegionAvail(ctx), ImGui.GetWindowHeight(ctx), false, nil) then
		ControllerPanel()
		ImGui.EndChild(ctx)
	end

	-- ACTIONS

	-- Plugin list selection
	if MOVE_TO_SELECTED_AREA then
		MOVE_TO_SELECTED_AREA = false
		MoveToSelectedArea()
	elseif SELECT_ALL_AVAILABLE then
		SELECT_ALL_AVAILABLE = false
		SelectAll(plugins.sel_available, params.filter_available)
	elseif UNSELECT_ALL_AVAILABLE then
		UNSELECT_ALL_AVAILABLE = false
		UnselectAll(plugins.sel_available, params.filter_available)
	elseif MOVE_TO_AVAILABLE_AREA then
		MOVE_TO_AVAILABLE_AREA = false
		MoveToAvailableArea()
	elseif SELECT_ALL_SELECTED then
		SELECT_ALL_SELECTED = false
		SelectAll(plugins.sel_selected, params.filter_selected)
	elseif UNSELECT_ALL_SELECTED then
		UNSELECT_ALL_SELECTED = false
		UnselectAll(plugins.sel_selected, params.filter_selected)
	------------------------------------------------------------------------------
	-- Background
	------------------------------------------------------------------------------
	elseif GENERATE_TOOLBAR_BACKGROUND then
		local b = params.toolbar_thumbnail.background
		local path = datapath .. b.preview_name
		ExportBackground(b, path)
		if ImGui.ValidatePtr(b.preview, "ImGui_Image*") then
			reaper.ImGui_Detach(ctx, b.preview)
		end
		b.preview = reaper.ImGui_CreateImage(path)
		reaper.ImGui_Attach(ctx, b.preview)
		TOOLBAR_BACKGROUND_PARAMS = deepcopy(b)
		BACKGROUND_READY = true
		GENERATE_TOOLBAR_BACKGROUND = false
	--
	elseif GENERATE_ICON_BACKGROUND then
		local b = params.thumbnail.background
		local path = datapath .. b.preview_name
		ExportBackground(b, path)
		if ImGui.ValidatePtr(b.preview, "ImGui_Image*") then
			reaper.ImGui_Detach(ctx, b.preview)
		end
		b.preview = reaper.ImGui_CreateImage(path)
		reaper.ImGui_Attach(ctx, b.preview)
		ICON_BACKGROUND_PARAMS = deepcopy(params.toolbar_thumbnail.background)
		BACKGROUND_READY = true
		-- msg("GENERATE ICON: ICON_BACKGROUND_READY " .. tostring(BACKGROUND_READY))
		GENERATE_ICON_BACKGROUND = false
	-- export
	elseif EXPORT_BACKGROUND_TOOLBAR then
		EXPORT_BACKGROUND_TOOLBAR = false
		DialogExportBackground(params.toolbar_thumbnail.background)
	elseif EXPORT_BACKGROUND_ICON then
		EXPORT_BACKGROUND_ICON = false
		DialogExportBackground(params.thumbnail.background)
	------------------------------------------------------------------------------
	-- Screenshot
	------------------------------------------------------------------------------
	elseif START_SCREENSHOT then
		-- initialisation
		-- if START_SCREENSHOT then
		START_SCREENSHOT = false
		-- gather selected plugin list
		SELECTED_PLUGS_TITLES = {}
		SELECTED_PLUGS = {}
		for i, sel in ipairs(plugins.sel_available) do
			if sel then
				SELECTED_PLUGS_TITLES[#SELECTED_PLUGS_TITLES + 1] = plugin_list[i].title
				SELECTED_PLUGS[#SELECTED_PLUGS + 1] = plugin_list[i]
			end
		end
		if #SELECTED_PLUGS == 0 then
			reaper.MB("No plugin selected", "Error", 0)
		else
			-- parameter saving, resources allocations and initialisations
			P = deepcopy(params)

			TRACK, _ = InsertDummyTrack()
			if P.thumbnail.do_thumbnail then
				T_BACKGROUND = GenerateBackground(P.thumbnail.background)
			end
			if P.toolbar_thumbnail.do_thumbnail then
				TBT_BACKGROUND = GenerateBackground(P.toolbar_thumbnail.background)
			end

			PROCESS_NEXT_FX = true
			INDEX = 1
			CREATE = true
			WAITING = false
			PROCESS = GetProcessingFunction()
			NEXT_ACTION = Iteration
		end
	elseif PROCESS_NEXT_FX then
		-- if PROCESS_NEXT_FX then
		if INDEX == #SELECTED_PLUGS then
			------- ENDING CODE HERE --------
			PROCESS_NEXT_FX = false
			NEXT_ACTION = Ending
		end
		local fxname = SELECTED_PLUGS_TITLES[INDEX]

		if not WAITING then
			WAITING = true
			ScreenshotFX_WithProcess(TRACK, fxname, params.delay_s, PROCESS, true, NEXT_ACTION)
		end
	end
end -- Main

function Run()
	if set_dock_id then
		reaper.ImGui_SetNextWindowDockID(ctx, set_dock_id)
		set_dock_id = nil
	end

	local imgui_visible, imgui_open = reaper.ImGui_Begin(ctx, input_title, true, reaper.ImGui_WindowFlags_NoCollapse())

	if imgui_visible then
		imgui_width, imgui_height = reaper.ImGui_GetWindowSize(ctx)

		Main()

		--------------------

		reaper.ImGui_End(ctx)
	end

	if imgui_open and not reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) and not process then
		reaper.defer(Run)
	end
end -- END DEFER

----------------------------------------------------------------------
-- RUN --
----------------------------------------------------------------------

function Init()
	SetButtonState(1)
	reaper.atexit(Exit)

	ctx = reaper.ImGui_CreateContext(input_title)

	reaper.defer(Run)
end

Init()
