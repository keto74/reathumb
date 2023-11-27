-- compute proportional scaling dimensions
-- return w, h
function PropScalingDim(iw, ih, ow, oh)
	local ratio = math.min(ow / iw, oh / ih)
	h = math.floor(ratio * ih)
	w = math.floor(ratio * iw)
	return w, h
end

-- scale img proportionally to fit on background and overlay it (centered)
function ScaledOverlay(dest, img)
	local h, w = reaper.JS_LICE_GetHeight(img), reaper.JS_LICE_GetWidth(img)
	local dh, dw = reaper.JS_LICE_GetHeight(dest), reaper.JS_LICE_GetWidth(dest)
	local sw, sh = PropScalingDim(w, h, dw, dh)
	local offx, offy = math.floor((dw - sw) / 2), math.floor((dh - sh) / 2)

	reaper.JS_LICE_ScaledBlit(dest, offx, offy, sw, sh, img, 0, 0, w, h, 1, "")
end

-- crop img
function CreateCrop(img, left, right, top, bottom)
	local h, w = reaper.JS_LICE_GetHeight(img), reaper.JS_LICE_GetWidth(img)
	local dh, dw = h - top - bottom, w - left - right
	local bmp = reaper.JS_LICE_CreateBitmap(true, dw, dh)
	reaper.JS_LICE_Blit(bmp, 0, 0, img, left, top, left + dw, top + dh, 1, "")
	return bmp
end

-- create a toolbar thumbnail from img with a color overlay on hover and click
function CreateToolbarThumbnail(img, argb_hover, argb_click)
	local h, w = reaper.JS_LICE_GetHeight(img), reaper.JS_LICE_GetWidth(img)
	local icon = reaper.JS_LICE_CreateBitmap(true, 3 * w, h)
	reaper.JS_LICE_Blit(icon, 0, 0, img, 0, 0, w, h, 1, "")
	reaper.JS_LICE_Blit(icon, w, 0, img, 0, 0, w, h, 1, "")
	reaper.JS_LICE_FillRect(icon, w, 0, w, h, argb_hover, 1, "OVERLAY")
	reaper.JS_LICE_Blit(icon, 2 * w, 0, img, 0, 0, w, h, 1, "")
	reaper.JS_LICE_FillRect(icon, 2 * w, 0, w, h, argb_click, 1, "OVERLAY")
	return icon
end

function CreateColorImage(argb, w, h)
	local img = reaper.JS_LICE_CreateBitmap(true, w, h)
	reaper.JS_LICE_FillRect(img, 0, 0, w, h, argb, 1, "")
	return img
end

function RGBA2ARGB(rgba)
	native_color_for_reaper = reaper.ImGui_ColorConvertNative(rgba >> 8)
	return (rgba >> 8 & 0x00FFFFFF) | (rgba << 24 & 0xFF000000)
end

function Unpack2Bytes4(argb)
	local b = argb & 0x000000FF
	argb = argb >> 16
	local g = argb & 0x000000FF
	argb = argb >> 16
	local r = argb & 0x000000FF
	argb = argb >> 16
	local a = argb & 0x000000FF
	return a, r, g, b
end

function Pack2Bytes4(a, r, g, b)
	return a << 48 | r << 32 | g << 16 | b
end

-- -- Create a linear gradient between two RGB colors
-- function LinearGradient(bitmap, x1, y1, x2, y2, color1, color2, steps)
-- 	local a1, r1, g1, b1 = Unpack2Bytes4(color1)
-- 	local a2, r2, g2, b2 = Unpack2Bytes4(color2)
--
-- 	for i = 0, steps - 1 do
-- 		local t = i / (steps - 1)
-- 		local r = r1 + (r2 - r1) * t
-- 		local g = g1 + (g2 - g1) * t
-- 		local b = b1 + (b2 - b1) * t
-- 		local a = a1 + (a2 - a1) * t
-- 		local color = Pack2Bytes4(math.floor(a), math.floor(r), math.floor(g), math.floor(b))
--
-- 		local x, y = x1 + (x2 - x1) * t, y1 + (y2 - y1) * t
-- 		reaper.JS_LICE_FillRect(bitmap, math.floor(x), math.floor(y), 1, 1, color, 1, "OVERLAY")
-- 	end
-- 	return bitmap
-- end
--
-- -- Create a radial gradient between two RGB colors
-- function RadialGradient(bitmap, x, y, radius, color1, color2, steps)
-- 	local a1, r1, g1, b1 = Unpack2Bytes4(color1)
-- 	local a2, r2, g2, b2 = Unpack2Bytes4(color2)
--
-- 	for i = 0, steps - 1 do
-- 		local t = i / (steps - 1)
-- 		local r = r1 + (r2 - r1) * t
-- 		local g = g1 + (g2 - g1) * t
-- 		local b = b1 + (b2 - b1) * t
-- 		local a = a1 + (a2 - a1) * t
--
-- 		local angle = 2 * math.pi * t
-- 		local px = x + radius * math.cos(angle)
-- 		local py = y + radius * math.sin(angle)
-- 		local color = Pack2Bytes4(math.floor(a), math.floor(r), math.floor(g), math.floor(b))
--
-- 		reaper.JS_LICE_FillRect(bitmap, math.floor(px), math.floor(py), 1, 1, color, 1, "OVERLAY")
-- 	end
-- 	return bitmap
-- end
--
-- -- Create a conic gradient between two RGB colors
-- function ConicGradient(bitmap, x, y, angle, color1, color2, steps)
-- 	local a1, r1, g1, b1 = Unpack2Bytes4(color1)
-- 	local a2, r2, g2, b2 = Unpack2Bytes4(color2)
-- 	local a = a1 + (a2 - a1) * t
--
-- 	for i = 0, steps - 1 do
-- 		local t = i / (steps - 1)
-- 		local r = r1 + (r2 - r1) * t
-- 		local g = g1 + (g2 - g1) * t
-- 		local b = b1 + (b2 - b1) * t
--
-- 		local px = x + math.cos(angle + 2 * math.pi * t)
-- 		local py = y + math.sin(angle + 2 * math.pi * t)
-- 		local color = Pack2Bytes4(math.floor(a), math.floor(r), math.floor(g), math.floor(b))
--
-- 		reaper.JS_LICE_FillRect(bitmap, math.floor(px), math.floor(py), 1, 1, color, 1, "OVERLAY")
-- 	end
-- 	return bitmap
-- end

-- function lerpColor(color1, color2, t)
-- 	-- return (color1 & 0xFFFFFF) + math.floor(((color2 & 0xFFFFFF) - (color1 & 0xFFFFFF)) * t)
-- 	return color1 + math.floor((color2 - color1) * t)
-- end

function LerpColor(a1, r1, g1, b1, a2, r2, g2, b2, t)
	local a = math.floor(a1 + (a2 - a1) * t)
	local r = math.floor(r1 + (r2 - r1) * t)
	local g = math.floor(g1 + (g2 - g1) * t)
	local b = math.floor(b1 + (b2 - b1) * t)
	return a, r, g, b
end

function ExtractColorComponents(argb)
	local a = (argb >> 24) & 0xFF
	local r = (argb >> 16) & 0xFF
	local g = (argb >> 8) & 0xFF
	local b = argb & 0xFF

	return a, r, g, b
end

function AssembleColorComponents(a, r, g, b)
	return (a << 24) | (r << 16) | (g << 8) | b
end

function LinearHorizontalGradient(bitmap, x1, x2, argb1, argb2)
	local width = reaper.JS_LICE_GetWidth(bitmap)
	local height = reaper.JS_LICE_GetHeight(bitmap)

	local a1, r1, g1, b1 = ExtractColorComponents(argb1)
	local a2, r2, g2, b2 = ExtractColorComponents(argb2)

	for y = 0, height - 1 do
		for x = 0, width - 1 do
			-- local t = math.min(math.max((x + x1), 0), width - 1) / (width - 1)
			local t = (x - x1) / (x2 - x1)
			if t < 0 then
				t = 0
			end

			-- Ensure the gradient stops after x2
			if t > 1 then
				t = 1
			end

			local a, r, g, b = LerpColor(a1, r1, g1, b1, a2, r2, g2, b2, t)
			local argb = AssembleColorComponents(a, r, g, b)

			reaper.JS_LICE_FillRect(bitmap, x, y, 1, 1, argb, 1.0, "COPY")
		end
	end
	return bitmap
end

function LinearGradient(bitmap, x1, x2, y1, y2, argb1, argb2)
	local width = reaper.JS_LICE_GetWidth(bitmap)
	local height = reaper.JS_LICE_GetHeight(bitmap)

	local a1, r1, g1, b1 = ExtractColorComponents(argb1)
	local a2, r2, g2, b2 = ExtractColorComponents(argb2)

	local dx = x2 - x1
	local dy = y2 - y1

	for y = 0, height - 1 do
		for x = 0, width - 1 do
			local t1 = (x - x1) / dx
			local t2 = (y - y1) / dy

			t1 = math.min(math.max(t1, 0), 1)
			t2 = math.min(math.max(t2, 0), 1)
			local t = (t1 + t2) / 2

			local a, r, g, b = LerpColor(a1, r1, g1, b1, a2, r2, g2, b2, t)
			local argb = AssembleColorComponents(a, r, g, b)

			reaper.JS_LICE_FillRect(bitmap, x, y, 1, 1, argb, 1.0, "COPY")
		end
	end
	return bitmap
end

function LinearHGradient(bitmap, x1, x2, argb1, argb2)
	local width = reaper.JS_LICE_GetWidth(bitmap)
	local height = reaper.JS_LICE_GetHeight(bitmap)

	local a1, r1, g1, b1 = ExtractColorComponents(argb1)
	local a2, r2, g2, b2 = ExtractColorComponents(argb2)

	local dx = x2 - x1

	for y = 0, height - 1 do
		for x = 0, x1 do
			reaper.JS_LICE_FillRect(bitmap, x, y, 1, 1, argb1, 1.0, "COPY")
		end
		for x = x1 + 1, x2 - 1 do
			local t = (x - x1) / dx

			local a, r, g, b = LerpColor(a1, r1, g1, b1, a2, r2, g2, b2, t)
			local argb = AssembleColorComponents(a, r, g, b)

			reaper.JS_LICE_FillRect(bitmap, x, y, 1, 1, argb, 1.0, "COPY")
		end
		for x = x2, width - 1 do
			reaper.JS_LICE_FillRect(bitmap, x, y, 1, 1, argb2, 1.0, "COPY")
		end
	end

	return bitmap
end

function LinearVGradient(bitmap, y1, y2, argb1, argb2)
	local width = reaper.JS_LICE_GetWidth(bitmap)
	local height = reaper.JS_LICE_GetHeight(bitmap)

	local a1, r1, g1, b1 = ExtractColorComponents(argb1)
	local a2, r2, g2, b2 = ExtractColorComponents(argb2)

	local dy = y2 - y1

	for y = 0, y1 do
		for x = 0, width - 1 do
			reaper.JS_LICE_FillRect(bitmap, x, y, 1, 1, argb1, 1.0, "COPY")
		end
	end
	for y = y1 + 1, y2 do
		for x = 0, width - 1 do
			local t = (y - y1) / dy

			local a, r, g, b = LerpColor(a1, r1, g1, b1, a2, r2, g2, b2, t)
			local argb = AssembleColorComponents(a, r, g, b)

			reaper.JS_LICE_FillRect(bitmap, x, y, 1, 1, argb, 1.0, "COPY")
		end
	end
	for y = y2, height - 1 do
		for x = 0, width - 1 do
			reaper.JS_LICE_FillRect(bitmap, x, y, 1, 1, argb2, 1.0, "COPY")
		end
	end

	return bitmap
end

function RadialGradient(bitmap, x, y, radius, argb1, argb2)
	local width = reaper.JS_LICE_GetWidth(bitmap)
	local height = reaper.JS_LICE_GetHeight(bitmap)

	local a1, r1, g1, b1 = ExtractColorComponents(argb1)
	local a2, r2, g2, b2 = ExtractColorComponents(argb2)

	for yPixel = 0, height - 1 do
		for xPixel = 0, width - 1 do
			local distance = math.sqrt((xPixel - x) ^ 2 + (yPixel - y) ^ 2)
			local t = distance / radius
			t = math.min(t, 1)

			local a, r, g, b = LerpColor(a1, r1, g1, b1, a2, r2, g2, b2, t)
			local argb = AssembleColorComponents(a, r, g, b)

			reaper.JS_LICE_FillRect(bitmap, xPixel, yPixel, 1, 1, argb, 1.0, "COPY")
		end
	end
	return bitmap
end

function ConicGradient(bitmap, x, y, angle, argb1, argb2)
	local width = reaper.JS_LICE_GetWidth(bitmap)
	local height = reaper.JS_LICE_GetHeight(bitmap)

	local a1, r1, g1, b1 = ExtractColorComponents(argb1)
	local a2, r2, g2, b2 = ExtractColorComponents(argb2)

	for yPixel = 0, height - 1 do
		for xPixel = 0, width - 1 do
			local deltaX = xPixel - x
			local deltaY = yPixel - y
			local pixelAngle = math.atan(deltaY, deltaX)

			if pixelAngle < 0 then
				pixelAngle = pixelAngle + (2 * math.pi)
			end

			local t = (pixelAngle - angle) / (2 * math.pi)
			t = math.min(math.max(t, 0), 1)

			local a, r, g, b = LerpColor(a1, r1, g1, b1, a2, r2, g2, b2, t)
			local argb = AssembleColorComponents(a, r, g, b)

			reaper.JS_LICE_FillRect(bitmap, xPixel, yPixel, 1, 1, argb, 1.0, "COPY")
		end
	end
	return bitmap
end

function CreateCopy(bitmap)
	local w, h = reaper.JS_LICE_GetWidth(bitmap), reaper.JS_LICE_GetHeight(bitmap)
	local copy = reaper.JS_LICE_CreateBitmap(true, w, h)
	reaper.JS_LICE_Blit(copy, 0, 0, bitmap, 0, 0, w, h, 1, "")
	return copy
end

function ToolbarIconFileSplit(icon_path, path_original, path_hovered, path_clicked)
	local icon = reaper.JS_LICE_LoadPNG(icon_path)
	local w, h = reaper.JS_LICE_GetWidth(icon), reaper.JS_LICE_GetHeight(icon)
	local bmp = reaper.JS_LICE_CreateBitmap(true, w / 3, h)
	local dw = w / 3
	reaper.JS_LICE_Blit(bmp, 0, 0, icon, 0, 0, dw, h, 1, "")
	reaper.JS_LICE_WritePNG(path_original, bmp, false)
	reaper.JS_LICE_Blit(bmp, 0, 0, icon, dw, 0, dw, h, 1, "")
	reaper.JS_LICE_WritePNG(path_hovered, bmp, false)
	reaper.JS_LICE_Blit(bmp, 0, 0, icon, dw << 1, 0, dw, h, 1, "")
	reaper.JS_LICE_WritePNG(path_clicked, bmp, false)
	reaper.JS_LICE_DestroyBitmap(icon)
	reaper.JS_LICE_DestroyBitmap(bmp)
end
