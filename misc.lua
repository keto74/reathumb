function msg(txt)
	reaper.MB(txt, "", 0)
end

-- get hardware window x, y, h and w
function GetWinXYHW(hwnd)
	local _, left, top, right, bottom = reaper.JS_Window_GetRect(hwnd)
	return left, top, right - left, bottom - top
end

function file_exists(path)
	local f = io.open(path, "rb")
	if f then
		f:close()
	end
	return f ~= nil
end

function lines_from(path)
	if not file_exists(path) then
		return {}
	end
	local lines = {}
	for line in io.lines(path) do
		lines[#lines + 1] = line
	end
	return lines
end

function GetFxList()
	local path = reaper.GetResourcePath() .. "/reaper-vstplugins64.ini"
	local lines = lines_from(path)
	local all_fx = {}
	for i = 2, #lines do
		local line = lines[i]
    if line == nil then
      goto continue
    end
		local fname, title_extra = string.match(line, "([^=]+)=[^,]+,[^,]+,([^)]+%))")
    if fname == nil or title_extra == nil then
      goto continue
    end
    -- if title_extra ~= nil then
    local title = string.match(title_extra, "([^)]+%))")
    if title == nil then
      goto continue
    end
    all_fx[#all_fx + 1] = {
      fname = fname,
      title = title,
    }
    ::continue::
	end
	return all_fx
end

-- return track, track index
function InsertDummyTrack()
	local trackidx = reaper.CountTracks(0)
	reaper.InsertTrackAtIndex(trackidx, true)
	track = reaper.GetTrack(0, trackidx)
	reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "__DUMMY__", true)
	return track, trackidx
end

function ParseReaperFxOptions()
	local opts = {}
	local path = reaper.GetResourcePath() .. "/reaper-fxoptions.ini"
	local lines = lines_from(path)
	for i = 2, #lines do
		local line = lines[i]
		local fname, id, action_id = string.match(line, "([^=]+)=([^:]+):(.+)")
		opts[fname] = {
			id = tonumber(id),
			action_id = action_id,
		}
	end
	return opts
end

function MaxFxOptionsId(opts)
	local max = 0
	if #opts > 0 then
		for _, opt in pairs(opts) do
			max = math.max(max, opt.id)
		end
		return max
	end
	return 1000000
end

function FormatReaperFxOptions(options)
	local txt = "[shortcut]\n"
	for fname, opt in pairs(options) do
		txt = string.format("%s%s=%d:%s\n", txt, fname, opt.id, opt.action_id)
	end
	return txt
end

function OverwriteReaperFxOptions(options, path)
	if path == nil then
		path = reaper.GetResourcePath() .. "/reaper-fxoptions.ini"
	end
	local fp = io.open(path, "w+")
	io.output(fp)
	local txt = FormatReaperFxOptions(options)
	io.write(txt)
	io.close(fp)
end

function GetFilename(path)
	local start, finish = path:find("[%w%s!-={-|]+[_%.].+")
	return path:sub(start, #path)
end

function ParseReaperMenu()
	function is_blank(s)
		return #string.gsub(s, "^%s*(.-)%s*$", "%1") == 0
	end
	function is_floating(section)
		return section:sub(1, 1) == "F"
	end

	local all_toolbars = {}
	local floating_keys = {}
	for i = 1, 32 do
		floating_keys[i] = nil
	end

	local lines = lines_from(reaper.GetResourcePath() .. "/reaper-menu.ini")
	local current_section = {}
	for i = 1, #lines do
		local line = lines[i]
		if is_blank(line) then
			goto continue
		end
		local section = string.match(line, "%s*%[([^%]]+)%]%s*")
		if section then
			current_section = {
				title = "",
				items = {},
				icons = {},
			}
			all_toolbars[section] = current_section
			if is_floating(section) then
				local id = tonumber(string.match(section, "Floating toolbar (%d+)"))
				floating_keys[id] = section
			end
			goto continue
		end
		local key, val = string.match(line, "([^=]+)=(.+)")
		if key == "title" then
			current_section.title = val
			goto continue
		end
		local key_type, key_id = string.match(key, "([^_]+)_(%d+)")

		-- in case items are not sorted...
		for _ = #current_section.items, key_id do
			current_section.items[#current_section.items + 1] = nil
		end
		if key_type == "icon" then
			-- icons keys are string so that items can skip icons
			current_section.icons[key_id] = val
			goto continue
		end
		if key_type == "item" then
			local action_id, action_name = string.match(val, "_([^ ]+) (.+)")
			-- key_id-s are 0-indexed
			current_section.items[tonumber(key_id) + 1] = {
				action_id = action_id,
				action_name = action_name,
			}
		end
		::continue::
	end
	return all_toolbars, floating_keys
end

function FormatReaperMenu(all_toolbars)
	local txt = ""
	for section, tb in pairs(all_toolbars) do
		txt = string.format("%s[%s]\ntitle=%s\n", txt, section, tb.title)
		for i, item in ipairs(tb.items) do
			txt = string.format("%sitem_%d=_%s %s\n", txt, i - 1, item.action_id, item.action_name)
		end
		for i, icon in pairs(tb.icons) do
			txt = string.format("%sicon_%s=%s\n", txt, i, icon)
		end
		txt = txt .. "\n"
	end
	return txt
end

function OverwriteReaperMenu(all_toolbars, path)
	if path == nil then
		path = reaper.GetResourcePath() .. "/reaper-menu.ini"
	end
	local fp = io.open(path, "w+")
	io.output(fp)
	local txt = FormatReaperMenu(all_toolbars)
	io.write(txt)
	io.close(fp)
end

function FXNameToActionID(fxname)
	local action_id = fxname:gsub(" ", "")
	action_id = action_id:gsub("%.", "")
	action_id = string.format("MY%s%s", action_id, tostring(math.random(1000, 10000)))
	return action_id
end

function FormatForFilename(s)
	s = s:gsub(" ", "_")
	s = s:gsub("%(", "_")
	s = s:gsub("%)", "_")
	return s
end

function deferWithArgs(func, ...)
	local t = { ... }
	return function()
		func(table.unpack(t))
	end
end

function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == "table" then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end


function any(t)
  for _, v in ipairs(t) do
    if v then return true end
  end
  return false
end

function countTrue(t)
  local c = 0
  for _, v in ipairs(t) do
    if v then
      c = c + 1
    end
  end
  return c
end
