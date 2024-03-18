local pixel_utils = {}

---@param pixels integer
---@param scale float | nil
---@return float
function pixel_utils.pixels_to_tiles(pixels, scale)
	return pixels * (scale or 1) / 32
end

---@param tiles float
---@param scale float | nil
---@return integer
function pixel_utils.tiles_to_pixels(tiles, scale)
	return math.floor(tiles * 32 / (scale or 1))
end

return pixel_utils
