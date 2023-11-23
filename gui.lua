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

-- Initial parsing
local plugin_list = GetFxList()
local toolbars, floating_keys = ParseReaperMenu()
local fxopts = ParseReaperFxOptions()

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
	do_raw = true,
	destination  = thispath.."raw",
	background = {
		mode = 1, -- gradient
		color = 0x72909ac8,
		width = 400,
		height = 200,
		gradient = 1, -- linear
		color1 = 0x72909aff,
		color2 = 0xddddddff,
		file = thispath .. "background_example.png",
	},
}

params.thumbnail = {
	do_thumbnail = true,
	destination  = thispath.."thumbnails",
	background = {
		mode = 1, -- gradient
		color = 0x72909ac8,
		width = 400,
		height = 200,
		gradient = 1, -- linear
		color1 = 0x000000ff,
		color2 = 0xffffffff,
		steps = 50,
		conic = {
			x = nil,
			y = nil,
			angle = math.pi/4,
		},
		linear = {
			h ={
				x1 = nil,
				x2 = nil,
			},
			mix ={
				x1 = nil,
				x2 = nil,
				y1 = nil,
				y2 = nil,
			},
			v ={
				y1 = nil,
				y2 = nil,
			},
			mode = 2
		},
		radial = {
			x = nil,
			y = nil,
			radius = nil,
		},
		file = thispath .. "background_example.png",
	},
	fname_prefix = "thumb_",
	fname_suffix = "",
}

params.toolbar_thumbnail = {
	do_thumbnail = true,
	destination  = thispath.."toolbar_thumbnails",
	background = {
		mode = 1,
		color = 0x72909ac8,
		width = 400,
		height = 200,
		gradient = 1, -- linear
		color1 = 0x000000ff,
		color2 = 0xffffffff,
		steps = 50,
		conic = {
			x = nil,
			y = nil,
			angle = math.pi/4,
		},
		linear = {
			h ={
				x1 = nil,
				x2 = nil,
			},
			mix ={
				x1 = nil,
				x2 = nil,
				y1 = nil,
				y2 = nil,
			},
			v ={
				y1 = nil,
				y2 = nil,
			},
			mode = 2
		},
		radial = {
			x = nil,
			y = nil,
			radius = nil,
		},
		file = thispath .. "background_example.png",
	},
	fname_prefix = "tb_thumb_",
	fname_suffix = "",
	color_hover = 0x349F3488,
	color_click = 0x9A0E0E88,
}

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
	do_toolbar = true,
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
			false,
			window_flags
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
		local col1, col2 = RGBA2ARGB(p.color1), RGBA2ARGB(p.color2)
		local steps = p.steps
		if p.gradient == 0 then -- conic
			return ConicGradient(bmp, p.conic.x, p.conic.y, p.conic.angle, col1, col2, p.steps)
		elseif p.gradient == 1 then -- linear
			local pp = p.linear
			if pp.mode == 0 then -- Horizontal
				return LinearHGradient(bmp, p.linear.h.x1, p.linear.h.x2, col1, col2)
			elseif pp.mode == 2 then -- Vertical
				return LinearVGradient(bmp, p.linear.v.y1, p.linear.v.y2, col1, col2)
			else
				return LinearGradient(bmp, p.linear.mix.x1, p.linear.mix.x2, p.linear.mix.y1, p.linear.mix.y2, col1, col2)
			end
		else  -- radial
			return RadialGradient(bmp, p.radial.x, p.radial.y, p.radial.radius, col1, col2, p.steps)
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
	return string.format("%s%s%s%s.png", dir, prefix, fxname, suffix)
end


function controller_view()
	function crop_control()
		local pc = params.cropping
		_, pc.do_crop = reaper.ImGui_Checkbox(ctx, "Crop window borders", pc.do_crop)
		if pc.do_crop then
			if ImGui.TreeNode(ctx, "Cropping parameters") then
				--_, params.cropping.left = reaper.ImGui_SliderInt(ctx, "left", params.cropping.left, 0, 50)
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
		end
	end
	function background_control(p)
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
				end
			end
		elseif p.mode == 1 then -- Gradient
			reaper.ImGui_SameLine(ctx)
			_, p.width, p.height = reaper.ImGui_DragInt2(ctx, "Width x Height", p.width, p.height, 25, 2000)
			_, p.color1 = ImGui.ColorEdit4(ctx, "Color 1", p.color1, ImGui.ColorEditFlags_NoInputs())
			reaper.ImGui_SameLine(ctx)
			_, p.color2 = ImGui.ColorEdit4(ctx, "Color 2", p.color2, ImGui.ColorEditFlags_NoInputs())
			local combo_items = "Conic\0Linear\0Radial\0"
			_, p.gradient = ImGui.Combo(ctx, "Gradient type", p.gradient, combo_items)
			
			if p.gradient == 0 then -- conic
				local pp = p.conic
				if pp.x == nil then
					pp.x = p.width/2
					pp.y = p.height/2
				end
				_, pp.x = reaper.ImGui_DragInt(ctx, "x", pp.x, 1, 0, p.width - 1)
				_, pp.y = reaper.ImGui_DragInt(ctx, "y", pp.y, 1, 0, p.height - 1)
				_, pp.angle = reaper.ImGui_DragDouble(ctx, "angle (rad)", pp.angle, 1, 0, math.pi)
 
			elseif p.gradient == 1 then -- linear
				local pp = p.linear
				reaper.ImGui_SameLine(ctx)

				local linear_items = "Horizontal\0Mix\0Vertical\0"
				_, pp.mode = ImGui.Combo(ctx, "Mode", pp.mode, linear_items)
				
				if pp.mode == 0 then -- horizontal
					if pp.h.x1 == nil then
						pp.h.x1, pp.h.x2 = 0, p.width - 1
					end
					_, pp.h.x1, pp.h.x2 = reaper.ImGui_DragInt2(ctx, "X begin/end", pp.h.x1, pp.h.x2, 1) --, 0, p.width - 1)
				elseif pp.mode == 1 then -- mix
					_, pp.mix.x1, pp.mix.x2 = reaper.ImGui_DragInt2(ctx, "X begin/end", pp.mix.x1, pp.mix.x2, 1) --, 0, p.width - 1)
					reaper.ImGui_SameLine(ctx)
					_, pp.mix.y1, pp.mix.y2 = reaper.ImGui_DragInt2(ctx, "Y begin/end", pp.mix.y1, pp.mix.y2, 1) --, 0, p.height - 1)
				else -- vertical
					_, pp.v.y1, pp.v.y2 = reaper.ImGui_DragInt2(ctx, "Y begin/end", pp.v.y1, pp.v.y2, 1) --, 0, p.height - 1)
				end
			else -- radial
				local pp = p.radial
				if pp.x == nil then
					pp.x = p.width/2
					pp.y = p.height/2
					pp.radius = math.min(p.height, p.width)/2
				end
				_, pp.x = reaper.ImGui_DragInt(ctx, "x", pp.x, 1, 0, p.width - 1)
				_, pp.y = reaper.ImGui_DragInt(ctx, "y", pp.y, 1, 0, p.height - 1)
				-- local rad_max = math.max(p.height, p.width)/2
				_, pp.radius = reaper.ImGui_DragInt(ctx, "radius", pp.radius, 1) -- , 0, rad_max)
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
		if params.raw.do_raw then
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
		end
	end
	function thumbnail_control()
		local tb = params.thumbnail
		_, tb.do_thumbnail = reaper.ImGui_Checkbox(ctx, "Thumbnail", tb.do_thumbnail)
		if tb.do_thumbnail then
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
		end
	end
	function toolbar_maker_control()
		local tb = params.toolbar_maker
		_, tb.do_toolbar = reaper.ImGui_Checkbox(ctx, "Create toolbar", tb.do_toolbar)
		if tb.do_toolbar then
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
		end
	end
	function thumbnail_toolbar_control()
		local tb = params.toolbar_thumbnail
		_, tb.do_thumbnail = reaper.ImGui_Checkbox(ctx, "Toolbar thumbnail", tb.do_thumbnail)
		if tb.do_thumbnail then
			--               if reaper.ImGui_CollapsingHeader(ctx, "Toolbar creator") then
			if ImGui.TreeNode(ctx, "Toolbar thumbnail parameters") then
				background_control(tb.background)
				_, tb.color_hover =
					ImGui.ColorEdit4(ctx, "Hover overlay", tb.color_hover, ImGui.ColorEditFlags_NoInputs())
				reaper.ImGui_SameLine(ctx)
				_, tb.color_click =
					ImGui.ColorEdit4(ctx, "Click overlay", tb.color_click, ImGui.ColorEditFlags_NoInputs())
				_, tb.fname_prefix = ImGui.InputText(ctx, "Filename(s) prefix", tb.fname_prefix)
				_, tb.fname_suffix = ImGui.InputText(ctx, "Filename(s) suffix", tb.fname_suffix)
				toolbar_maker_control()
				ImGui.TreePop(ctx)
			end
			--               end
		end
	end
	if ImGui.BeginChild(ctx, "ChildR", ImGui.GetContentRegionAvail(ctx), ImGui.GetWindowHeight(ctx), false, nil) then
		ImGui.PushItemWidth(ctx, 100)
		_, params.delay_s = ImGui.SliderDouble(ctx, "Delay (s)", params.delay_s, 0.001, 3)
		crop_control()
		raw_control()
		thumbnail_control()
		thumbnail_toolbar_control()
		--toolbar_maker_control()
		ImGui.PopItemWidth(ctx)

		-- screenshot button
		if reaper.ImGui_Button(ctx, "Screenshot") then
			local selected_plugs_title = {}
			local selected_plugs = {}
			for i, sel in ipairs(params.sel_plug) do
				if sel then
					selected_plugs_title[#selected_plugs_title + 1] = plugin_list[i].title
					selected_plugs[#selected_plugs + 1] = plugin_list[i]
				end
			end
			local pt = params.thumbnail
			--[[if pt.background.linear.v.y1 == nil then
				msg("why y1!!!")
			end
			if pt.background.linear.v.y2 == nil then
				msg("why y2!!!")
			end]]--
			
			if #selected_plugs > 0 then
				local track, trackidx = InsertDummyTrack()
				local track = reaper.GetTrack(0, 0)
				local path = reaper.GetResourcePath() .. "/screenshots/"
				local delete_dummy_track = function()
					reaper.DeleteTrack(track)
				end
				-- Image processing function
				local process = function(bmp, fxname)
			
					local bmp2 = CreateCrop(
						bmp,
						params.cropping.left,
						params.cropping.right,
						params.cropping.top,
						params.cropping.bottom
					)
					
					-- Thumbnail
					local pt = params.thumbnail
					if pt.do_thumbnail then
						--[[if pt.background.linear.v.y1 == nil then
							msg("why y1!!!")
						end
						if pt.background.linear.v.y2 == nil then
							msg("why y2!!!")
						end]]--
						local background = create_background(pt.background)
						ScaledOverlay(bmp2, background)
  
						local t_path = ThumbnailPath(path, pt.fname_prefix, fxname, pt.fname_suffix)
						reaper.JS_LICE_WritePNG(t_path, background, false)
						reaper.JS_LICE_DestroyBitmap(background)
					end

					-- Toolbar thumbnail
					local ptbt = params.toolbar_thumbnail
					if ptbt.do_thumbnail then
						local background = create_background(ptbt.background)

						ScaledOverlay(bmp2, background)
						local tb_thumbnail = CreateToolbarThumbnail(
							background,
							RGBA2ARGB(ptbt.color_hover),
							RGBA2ARGB(ptbt.color_click)
						)
						local tbt_path = ThumbnailPath(path_toolbar_icons, ptbt.fname_prefix, fxname, ptbt.fname_suffix)
						reaper.JS_LICE_WritePNG(tbt_path, tb_thumbnail, false)
						reaper.JS_LICE_DestroyBitmap(tb_thumbnail)
						reaper.JS_LICE_DestroyBitmap(background)
					end

					-- Raw captures
					if params.raw.do_raw then
						local img_path = ThumbnailPath(path, "", filename, "")
						reaper.JS_LICE_WritePNG(img_path, bmp2, false)
					end
					
					reaper.JS_LICE_DestroyBitmap(bmp2)
					reaper.JS_LICE_DestroyBitmap(bmp)
					return bmp2
				end
				
				-- Start capture (will defer)
				ScreenshotFXList_WithProcess(
					track,
					selected_plugs_title,
					params.delay_s,
					process,
					nil,
					true,
					delete_dummy_track
				)
				
				-- Create toolbar
				if params.toolbar_maker.do_toolbar then
					local tbm = params.toolbar_maker
					local toolbar = {
						items = {},
						icons = {},
					}
					if floating_keys[tbm.toolbar] ~= nil and not tbm.overwrite then
						toolbar = toolbars[floating_keys[tbm.toolbar]]
					end
					if tbm.title == "" then
						toolbar.title = tb_title[tbm.toolbar]
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
					for _, fx in ipairs(selected_plugs) do
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
			else
				reaper.MB("No plugin selected", "Error", 0)
			end
		end
		ImGui.EndChild(ctx)
	end
end

----------------------------------------------------------------------
-- RUN --
----------------------------------------------------------------------
function Main()
	--------------------
	-- YOUR CODE HERE --
	--------------------

	plugin_list_view()
	ImGui.SameLine(ctx)
	controller_view()
end

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
