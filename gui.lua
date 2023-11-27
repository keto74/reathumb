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
local toolbars, floating_keys = ParseReaperMenu()
local fxopts = ParseReaperFxOptions()

-- defaults
local default_width, default_height = 400, 200
local default = {
	background = {
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
local params = {}
params.sel_plug = {}
for _ = 1, #plugin_list do
	params.sel_plug[#params.sel_plug + 1] = false
end

params.delay_s = 0.5
params.cropping = {
	do_crop = true,
	left = 10,
	right = 10,
	top = 60,
	bottom = 10,
}

params.raw = {
	do_raw = false,
	destination = thispath .. "raw",
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
params.thumbnail.background.preview_name = "background_thumbnail.png"

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
params.toolbar_thumbnail.background.preview_name = "background_toolbar_thumbnail.png"

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

function plugin_list_view()
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
		-- select all
		if reaper.ImGui_Button(ctx, "All") then
			for i = 1, #params.sel_plug do
				params.sel_plug[i] = true
			end
		end
		reaper.ImGui_SameLine(ctx)
		if reaper.ImGui_Button(ctx, "None") then
			for i = 1, #params.sel_plug do
				params.sel_plug[i] = false
			end
		end
		for i, sel in ipairs(params.sel_plug) do
			if reaper.ImGui_Selectable(ctx, ("%d: %s"):format(i, plugin_list[i].title), sel) then
				if not reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) then -- Clear selection when CTRL is not heldk
					for j = 1, #params.sel_plug do
						params.sel_plug[j] = false
					end
				end
				params.sel_plug[i] = not sel
			end
		end
		ImGui.EndChild(ctx)
	end
end

function create_background(p)
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

function BeginDisabled(v)
	if v then
		reaper.ImGui_BeginDisabled(ctx)
	end
end
function EndDisabled(v)
	if v then
		reaper.ImGui_EndDisabled(ctx)
	end
end

try = {
	x0 = 0,
	x1 = 1,
	y0 = 0,
	y1 = 1,
}
function controller_view()
	function crop_control()
		local pc = params.cropping
		_, pc.do_crop = reaper.ImGui_Checkbox(ctx, "Crop window borders", pc.do_crop)
		BeginDisabled(not pc.do_crop)
		if ImGui.TreeNode(ctx, "Cropping parameters") then
			reaper.ImGui_PushItemWidth(ctx, 100)
			_, pc.top, pc.bottom = reaper.ImGui_DragInt2(ctx, "top/bottom", pc.top, pc.bottom, 1, 0, 100)
			_, pc.left, pc.right = reaper.ImGui_DragInt2(ctx, "left/right", pc.left, pc.right, 1, 0, 50)
			if reaper.ImGui_Button(ctx, "Reset") then
				params.cropping = {
					left = 10,
					right = 10,
					top = 60,
					bottom = 10,
				}
			end
			ImGui.TreePop(ctx)
		end
		EndDisabled(not pc.do_crop)
	end
	function background_control(p)
		function background_preview()
			if reaper.ImGui_Button(ctx, "Preview...") then
				if p.preview == nil then
					local background = create_background(p)
					local path = datapath .. p.preview_name
					p.preview = path
					reaper.JS_LICE_WritePNG(path, background, true)
					reaper.JS_LICE_DestroyBitmap(background)
				end
				reaper.ImGui_OpenPopup(ctx, "test")
				if reaper.ImGui_BeginPopupModal(ctx, "test") then
					local bitmap = reaper.ImGui_CreateImage(p.preview)
					local w, h = reaper.ImGui_Image_GetSize(bitmap)
					reaper.ImGui_Image(ctx, bitmap, w, h)
					reaper.ImGui_EndPopup(ctx)
				end
			end
		end
		local combo_items = "Color\0Gradient\0Image\0"
		_, p.mode = ImGui.Combo(ctx, "Background", p.mode, combo_items)
		if p.mode == 0 then -- Color
			reaper.ImGui_SameLine(ctx)
			_, p.width, p.height = reaper.ImGui_DragInt2(ctx, "width x height", p.width, p.height, 1, 25, 2000)
			_, p.color = ImGui.ColorEdit4(ctx, "Color", p.color, ImGui.ColorEditFlags_NoInputs())
			if reaper.ImGui_Button(ctx, "Save background...") then
				local rv, path = reaper.JS_Dialog_BrowseForSaveFile(
					"Save background",
					thispath,
					"background.png",
					"Image (PNG)\0*.png\0\0"
				)
				if rv ~= 0 then
					local background = create_background(p)
					reaper.JS_LICE_WritePNG(path, background, false)
					reaper.JS_LICE_DestroyBitmap(background)
					p.preview = path
				end
			end
			background_preview()
		elseif p.mode == 1 then -- Gradient
			local g = p.gradient
			reaper.ImGui_SameLine(ctx)
			_, p.width, p.height = reaper.ImGui_DragInt2(ctx, "Width x Height", p.width, p.height, 25, 2000)
			_, g.color1 = ImGui.ColorEdit4(ctx, "Color 1", g.color1, ImGui.ColorEditFlags_NoInputs())
			reaper.ImGui_SameLine(ctx)
			_, g.color2 = ImGui.ColorEdit4(ctx, "Color 2", g.color2, ImGui.ColorEditFlags_NoInputs())

			local combo_items = "Conic\0Linear\0Radial\0"
			_, g.mode = ImGui.Combo(ctx, "Gradient type", g.mode, combo_items)

			if g.mode == 0 then -- conic
				local c = p.conic
				if c.x == nil then
					c.x = p.width / 2
					c.y = p.height / 2
				end
				_, c.x = reaper.ImGui_DragInt(ctx, "x", c.x, 1, 0, p.width - 1)
				_, c.y = reaper.ImGui_DragInt(ctx, "y", c.y, 1, 0, p.height - 1)
				_, c.angle = reaper.ImGui_DragDouble(ctx, "angle (rad)", c.angle, 1, 0, math.pi)
			elseif g.mode == 1 then -- linear
				local l = g.linear
				reaper.ImGui_SameLine(ctx)

				local linear_items = "Horizontal\0Mix\0Vertical\0"
				_, l.mode = ImGui.Combo(ctx, "Mode", l.mode, linear_items)

				if l.mode == 0 then -- horizontal
					if l.h.x1 == nil then
						l.h.x1, l.h.x2 = 0, p.width - 1
					end
					_, l.h.x1, l.h.x2 = reaper.ImGui_DragInt2(ctx, "X begin/end", l.h.x1, l.h.x2, 1) --, 0, p.width - 1)
				elseif l.mode == 1 then -- mix
					if l.mix.x1 == nil then
						l.mix.x1, l.mix.x2 = 0, p.width - 1
						l.v.x1, l.v.x2 = 0, p.height - 1
					end
					_, l.mix.x1, l.mix.x2 = reaper.ImGui_DragInt2(ctx, "X begin/end", l.mix.x1, l.mix.x2, 1) --, 0, p.width - 1)
					reaper.ImGui_SameLine(ctx)
					_, l.mix.y1, l.mix.y2 = reaper.ImGui_DragInt2(ctx, "Y begin/end", l.mix.y1, l.mix.y2, 1) --, 0, p.height - 1)
				else -- vertical
					if l.v.y1 == nil then
						l.v.y1, l.v.y2 = 0, p.height - 1
					end
					_, l.v.y1, l.v.y2 = reaper.ImGui_DragInt2(ctx, "Y begin/end", l.v.y1, l.v.y2, 1) --, 0, p.height - 1)
				end
			else -- radial
				local r = p.radial
				if r.x == nil then
					r.x = p.width / 2
					r.y = p.height / 2
					r.radius = math.min(p.height, p.width) / 2
				end
				_, r.x = reaper.ImGui_DragInt(ctx, "x", r.x, 1, 0, p.width - 1)
				_, r.y = reaper.ImGui_DragInt(ctx, "y", r.y, 1, 0, p.height - 1)
				-- local rad_max = math.max(p.height, p.width)/2
				_, r.radius = reaper.ImGui_DragInt(ctx, "radius", r.radius, 1) -- , 0, rad_max)
			end
			if reaper.ImGui_Button(ctx, "Save background...") then
				local rv, path = reaper.JS_Dialog_BrowseForSaveFile(
					"Save background",
					thispath,
					"background.png",
					"Image (PNG)\0*.png\0\0"
				)
				if rv ~= 0 then
					local bg = create_background(p)
					reaper.JS_LICE_WritePNG(path, bg, false)
				end
			end
			background_preview()
		else
			if reaper.ImGui_Button(ctx, "File") then
				local rv, file = reaper.GetUserFileNameForRead("", "Image", ".png")
				if rv ~= 0 then
					p.file = file
				end
			end
			reaper.ImGui_SameLine(ctx)
			reaper.ImGui_Text(ctx, p.file)
		end
	end
	function raw_control()
		_, params.raw.do_raw = reaper.ImGui_Checkbox(ctx, "Raw image", params.raw.do_raw)
		BeginDisabled(not params.raw.do_raw)
		if ImGui.TreeNode(ctx, "Raw image parameters") then
			reaper.ImGui_Text(ctx, params.raw.destination)
			if reaper.ImGui_Button(ctx, "Destination...") then
				rv, folder = reaper.JS_Dialog_BrowseForFolder("Raw image destination", params.raw.destination)
				if rv ~= 0 then
					params.raw.destination = folder
				end
			end
			--reaper.ImGui_SameLine(ctx)
			--reaper.ImGui_Text(ctx, params.raw.destination)
			ImGui.TreePop(ctx)
		end
		EndDisabled(not params.raw.do_raw)
	end
	function thumbnail_control()
		local tb = params.thumbnail
		_, tb.do_thumbnail = reaper.ImGui_Checkbox(ctx, "Thumbnail", tb.do_thumbnail)
		BeginDisabled(not tb.do_thumbnail)
		if ImGui.TreeNode(ctx, "Thumbnail parameters") then
			reaper.ImGui_Text(ctx, tb.destination)
			if reaper.ImGui_Button(ctx, "Destination...") then
				rv, folder = reaper.JS_Dialog_BrowseForFolder("Thumbnails destination", tb.destination)
				if rv ~= 0 then
					tb.destination = folder
				end
			end
			reaper.ImGui_PushItemWidth(ctx, 80)
			_, tb.fname_prefix = ImGui.InputText(ctx, "Prefix", tb.fname_prefix)
			reaper.ImGui_SameLine(ctx)
			_, tb.fname_suffix = ImGui.InputText(ctx, "Suffix", tb.fname_suffix)
			reaper.ImGui_PopItemWidth(ctx)
			background_control(tb.background)
			ImGui.TreePop(ctx)
		end
		EndDisabled(not tb.do_thumbnail)
	end
	function toolbar_maker_control()
		local tb = params.toolbar_maker
		_, tb.do_toolbar = reaper.ImGui_Checkbox(ctx, "Create toolbar", tb.do_toolbar)
		BeginDisabled(not tb.do_toolbar)
		--if ImGui.TreeNode(ctx, "Toolbar creator parameters") then
		-- Combo
		local preview_value = items_tb[tb.toolbar]
		if ImGui.BeginCombo(ctx, "Toolbar", preview_value) then
			for i, v in ipairs(items_tb) do
				local is_selected = tb.toolbar == i
				if ImGui.Selectable(ctx, items_tb[i], is_selected) then
					tb.toolbar = i
				end

				-- Set the initial focus when opening the combo (scrolling + keyboard navigation focus)
				if is_selected then
					ImGui.SetItemDefaultFocus(ctx)
				end
			end
			ImGui.EndCombo(ctx)
		end
		-- End of combo
		if floating_keys[tb.toolbar] ~= nil then
			reaper.ImGui_SameLine(ctx)
			_, tb.overwrite = reaper.ImGui_Checkbox(ctx, "Overwrite", tb.overwrite)
		end
		_, tb.title = ImGui.InputText(ctx, "Title", tb.title)
		--     ImGui.TreePop(ctx)
		--end
		EndDisabled(not tb.do_toolbar)
	end
	function thumbnail_toolbar_control()
		local tb = params.toolbar_thumbnail
		_, tb.do_thumbnail = reaper.ImGui_Checkbox(ctx, "Toolbar thumbnail", tb.do_thumbnail)
		BeginDisabled(not tb.do_thumbnail)
		if ImGui.TreeNode(ctx, "Toolbar thumbnail parameters") then
			reaper.ImGui_Text(ctx, tb.destination)
			_, tb.default_destination =
				reaper.ImGui_Checkbox(ctx, "Reaper toolbar icons folder", tb.default_destination)
			if not tb.default_destination then
				if reaper.ImGui_Button(ctx, "Destination...") then
					rv, folder = reaper.JS_Dialog_BrowseForFolder("Thumbnails destination", tb.destination)
					if rv ~= 0 then
						tb.destination = folder
					end
				end
			end
			background_control(tb.background)
			_, tb.color_hover = ImGui.ColorEdit4(ctx, "Hover overlay", tb.color_hover, ImGui.ColorEditFlags_NoInputs())
			reaper.ImGui_SameLine(ctx)
			_, tb.color_click = ImGui.ColorEdit4(ctx, "Click overlay", tb.color_click, ImGui.ColorEditFlags_NoInputs())
			_, tb.fname_prefix = ImGui.InputText(ctx, "Filename(s) prefix", tb.fname_prefix)
			_, tb.fname_suffix = ImGui.InputText(ctx, "Filename(s) suffix", tb.fname_suffix)
			toolbar_maker_control()
			ImGui.TreePop(ctx)
		end
		EndDisabled(not tb.do_thumbnail)
	end
	function preview_image(title, p)
		if p.path ~= nil then
			if reaper.ImGui_Button(ctx, title) then
				reaper.ImGui_OpenPopup(ctx, title)
			end
			if reaper.ImGui_BeginPopup(ctx, title) then
				local bitmap = reaper.ImGui_CreateImage(p.path)
				local w, h = reaper.ImGui_Image_GetSize(bitmap)
				reaper.ImGui_Image(ctx, bitmap, w, h)
				reaper.ImGui_EndPopup(ctx)
			end
		end
	end
	function preview_toolbar_image(title, p)
		if p.path ~= nil then
			local open
			if reaper.ImGui_Button(ctx, title) then
				open = reaper.ImGui_OpenPopup(ctx, title)
			end
			reaper.ImGui_SameLine(ctx)
			_, p.real_mode = reaper.ImGui_Checkbox(ctx, "Realistic mode", p.real_mode)

			if reaper.ImGui_BeginPopup(ctx, title) then
				local bitmap = reaper.ImGui_CreateImage(p.path)
				local w, h = reaper.ImGui_Image_GetSize(bitmap)
				if p.real_mode then -- "realistic" toolbar thumbnail preview
					if p.mousestate == 0 then
						reaper.ImGui_Image(ctx, bitmap, w / 3, h, 0, 0, 1 / 3)
					elseif p.mousestate == 1 then
						reaper.ImGui_Image(ctx, bitmap, w / 3, h, 1 / 3, 0, 2 / 3)
					else
						reaper.ImGui_Image(ctx, bitmap, w / 3, h, 2 / 3, 0, 1)
					end
					p.mousestate = 0
					if reaper.ImGui_IsItemHovered(ctx) then
						p.mousestate = 1
					end
					if reaper.ImGui_IsItemClicked(ctx) then
						p.mousestate = 2
					end
				else -- full image preview
					reaper.ImGui_Image(ctx, bitmap, w, h)
				end
				reaper.ImGui_EndPopup(ctx)
			end
		end
	end
	if ImGui.BeginChild(ctx, "ChildR", ImGui.GetContentRegionAvail(ctx), ImGui.GetWindowHeight(ctx), false, nil) then
		ImGui.PushItemWidth(ctx, 100)

		-- UI --

		_, params.delay_s = ImGui.SliderDouble(ctx, "Delay (s)", params.delay_s, 0.001, 3)
		crop_control()
		raw_control()
		thumbnail_control()
		thumbnail_toolbar_control()

		--toolbar_maker_control()
		ImGui.PopItemWidth(ctx)
		-- screenshot button
		if reaper.ImGui_Button(ctx, "Screenshot") then
			START_SCREENSHOT = true
		end

		preview_image("Preview screenshot", params.raw.preview)
		preview_image("Preview thumbnail", params.thumbnail.preview)
		preview_toolbar_image("Preview toolbar thumbnail", params.toolbar_thumbnail.preview)

		ImGui.EndChild(ctx)
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
		--string.format("%s/%s%s%s.png", path_toolbar_icons, tt.fname_prefix, fx.title, tt.fname_suffix)
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
			--msg(img_path)
			RAW_PATH = img_path
		end

		-- Thumbnail
		if P.thumbnail.do_thumbnail then
			local p = P.thumbnail
			local background = CreateCopy(T_BACKGROUND)
			ScaledOverlay(background, cropped)

			local img_path = ThumbnailPath(p.destination, p.fname_prefix, fxname, p.fname_suffix)
			reaper.JS_LICE_WritePNG(img_path, background, false)
			--msg(img_path)

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
			--msg(img_path)

			reaper.JS_LICE_DestroyBitmap(tb_thumbnail)
			reaper.JS_LICE_DestroyBitmap(background)
			TBT_PATH = img_path
		end
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
	plugin_list_view()
	ImGui.SameLine(ctx)
	controller_view()

	-- Actions

	-- initialisation
	if START_SCREENSHOT then
		START_SCREENSHOT = false
		-- gather selected plugin list
		SELECTED_PLUGS_TITLES = {}
		SELECTED_PLUGS = {}
		for i, sel in ipairs(params.sel_plug) do
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
				T_BACKGROUND = create_background(P.thumbnail.background)
			end
			if P.toolbar_thumbnail.do_thumbnail then
				TBT_BACKGROUND = create_background(P.toolbar_thumbnail.background)
			end

			PROCESS_NEXT_FX = true
			INDEX = 1
			CREATE = true
			WAITING = false
			PROCESS = GetProcessingFunction()
			NEXT_ACTION = function()
				WAITING = false
				INDEX = INDEX + 1
			end
		end
	end

	if PROCESS_NEXT_FX then
		if INDEX == #SELECTED_PLUGS then
			------- ENDING CODE HERE --------
			PROCESS_NEXT_FX = false
			NEXT_ACTION = function()
				WAITING = false
				-- create toolbar when all icons have created to prevent issues after potential bugs/interruptions
				if P.toolbar_maker.do_toolbar then
					CreateToolbar()
				end
				-- resources deallocation
				reaper.DeleteTrack(TRACK)
				if P.thumbnail.do_thumbnail then
					reaper.ImGui_Image(ctx, bitmap, w / 3, h, 2 / 3, 0, 1)
					reaper.JS_LICE_DestroyBitmap(T_BACKGROUND)
				end
				if P.toolbar_thumbnail.do_thumbnail then
					reaper.JS_LICE_DestroyBitmap(TBT_BACKGROUND)
				end

				-- Setting up previews
				if P.raw.do_raw then
					params.raw.preview.path = RAW_PATH
				end
				if P.thumbnail.do_thumbnail then
					params.thumbnail.preview.path = T_PATH
				end
				if P.toolbar_thumbnail.do_thumbnail then
					params.toolbar_thumbnail.preview.path = TBT_PATH
				end
			end
		end
		local fxname = SELECTED_PLUGS_TITLES[INDEX]

		if WAITING then
			goto continue
		end

		WAITING = true
		ScreenshotFX_WithProcess(TRACK, fxname, params.delay_s, PROCESS, true, NEXT_ACTION)
	end

	::continue::
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
