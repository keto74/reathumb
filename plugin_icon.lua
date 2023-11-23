local thispath = ({ reaper.get_action_context() })[2]:match("^.+[\\//]")
dofile(thispath .. "/misc.lua")
dofile(thispath .. "/img.lua")

-- take a screenshot of an opened fx
-- return bmp
function CaptureOpenedFxFloatingWindow(track, fxname)
	local fxidx = reaper.TrackFX_GetByName(track, fxname, true)
	local hwnd = reaper.TrackFX_GetFloatingWindow(track, fxidx)
	if hwnd == nil then
		reaper.ReaScriptError(("Can't get floating window for FX %s"):format(fxname))
		return
	end
	local hwnd_dc = reaper.JS_GDI_GetWindowDC(hwnd)
	local _, _, w, h = GetWinXYHW(hwnd)

	local bmp = reaper.JS_LICE_CreateBitmap(true, w, h)
	local bmp_dc = reaper.JS_LICE_GetDC(bmp)
	reaper.JS_GDI_Blit(bmp_dc, 0, 0, hwnd_dc, 0, 0, w, h)
	reaper.JS_GDI_ReleaseDC(hwnd, bmp_dc)
	return bmp
end

-- Open a new fx on an existing track and take a screenshot
-- return bmp
function ScreenshotFX_WithProcess(track, fxname, delay_s, process_bmp, delete_fx, next_action)
	function load_fx_and_capture()
		local fxidx = reaper.TrackFX_GetByName(track, fxname, true)
		reaper.TrackFX_Show(track, fxidx, 3)
		time1 = reaper.time_precise()

		function wait_and_capture()
			local time2 = reaper.time_precise()
			if time2 - time1 < delay_s then
				reaper.defer(wait_and_capture)
			else
				bmp = CaptureOpenedFxFloatingWindow(track, fxname)
				process_bmp(bmp, fxname)

				if delete_fx then
					reaper.TrackFX_Delete(track, fxidx)
				end
				-- follow up action
				if next_action ~= nil then
					next_action()
				end
			end
		end

		wait_and_capture()
	end

	load_fx_and_capture()
end

function ScreenshotFXList_WithProcess(track, fxlist, delay_s, process_bmp, fname_func, delete_fx, next_action)
	if fname_func == nil then
		fname_func = function(fname)
			return fname
		end
	end
	function iter_foo(idx, track, fxlist, delay_s, process_bmp, delete_fx, next_action)
		if idx == #fxlist + 1 then
			if next_action ~= nil then
				next_action()
			end
			return
		end
		local iter_me = function()
			iter_foo(idx + 1, track, fxlist, delay_s, process_bmp, delete_fx, next_action)
		end
		local fxname = fxlist[idx]

		ScreenshotFX_WithProcess(track, fxname, delay_s, process_bmp, delete_fx, iter_me)
	end
	iter_foo(1, track, fxlist, delay_s, process_bmp, delete_fx, next_action)
end

function ScreenshotFX(track, fxname, delay_s, filename, delete_fx, next_action)
	function id(bmp)
		return bmp
	end
	ScreenshotFX_WithProcess(track, fxname, delay_s, id, filename, delete_fx, next_action)
end
