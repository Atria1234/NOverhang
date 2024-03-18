local pixel_utils = require('scripts.pixel-utils')

--- @class ExtendedBoundingBox
local extended_bounding_box = {
    left_top = {
        x = 0,
        y = 0
    },
    right_bottom = {
        x = 0,
        y = 0
    },
    center = {
        x = 0,
        y = 0
    },
    width = 0,
    height = 0
}

--- @param x float
--- @param y float
--- @param width float
--- @param height float
--- @return ExtendedBoundingBox
function extended_bounding_box:from_values(x, y, width, height)
    local instance = {}
    for key, value in pairs(self) do
        if type(value) == 'function' then
            instance[key] = value
        end
    end

    instance.left_top = {
        x = x,
        y = y
    }
    instance.right_bottom = {
        x = x + width,
        y = y + height
    }
    instance.center = {
        x = x + width / 2,
        y = y + height / 2
    }
    instance.width = width
    instance.height = height

    return instance
end

--- @param self ExtendedBoundingBox
--- @param parameters data.SpriteParameters
--- @return ExtendedBoundingBox
function extended_bounding_box:from_sprite_parameters_pixels(parameters)
	local x = parameters.x or parameters.position and parameters.position[1] or 0
	local y = parameters.y or parameters.position and parameters.position[2] or 0
	local width = parameters.size and (type(parameters.size) == 'number' and parameters.size or parameters.size[1]) or parameters.width
	local height = parameters.size and (type(parameters.size) == 'number' and parameters.size or parameters.size[2]) or parameters.height

    return self:from_values(x, y, width, height)
end

--- @param self ExtendedBoundingBox
--- @param parameters data.SpriteParameters
--- @return ExtendedBoundingBox
function extended_bounding_box:from_sprite_parameters_tiles(parameters)
	local width = parameters.size and (type(parameters.size) == 'number' and parameters.size or parameters.size[1]) or parameters.width
	local height = parameters.size and (type(parameters.size) == 'number' and parameters.size or parameters.size[2]) or parameters.height

    return self:from_dimensions(
        parameters.shift or { 0, 0 },
		{
            pixel_utils.pixels_to_tiles(width, parameters.scale),
            pixel_utils.pixels_to_tiles(height, parameters.scale)
        }
    )
end

--- @param bounding_box data.BoundingBox
--- @return ExtendedBoundingBox
function extended_bounding_box:from_bounding_box(bounding_box)
    local new_bounding_box = {
        left_top = {
            x = bounding_box.left_top and (bounding_box.left_top[1] or bounding_box.left_top.x) or bounding_box[1] and (bounding_box[1][1] or bounding_box[1].x),
            y = bounding_box.left_top and (bounding_box.left_top[2] or bounding_box.left_top.y) or bounding_box[1] and (bounding_box[1][2] or bounding_box[1].y)
        },
        right_bottom = {
            x = bounding_box.right_bottom and (bounding_box.right_bottom[1] or bounding_box.right_bottom.x) or bounding_box[1] and (bounding_box[2][1] or bounding_box[2].x),
            y = bounding_box.right_bottom and (bounding_box.right_bottom[2] or bounding_box.right_bottom.y) or bounding_box[1] and (bounding_box[2][2] or bounding_box[2].y)
        }
    }

    return self:from_values(
        new_bounding_box.left_top.x,
        new_bounding_box.left_top.y,
        new_bounding_box.right_bottom.x - new_bounding_box.left_top.x,
        new_bounding_box.right_bottom.y - new_bounding_box.left_top.y
    )
end

--- @param center data.MapPosition
--- @param size float | float[] | {width: float, height: float}
--- @return ExtendedBoundingBox
function extended_bounding_box:from_dimensions(center, size)
    local width = type(size) == 'number' and size or size[1] or size.width
    local height = type(size) == 'number' and size or size[2] or size.height

    return self:from_values(
        (center[1] or center.x) - width / 2,
        (center[2] or center.y) - height / 2,
        width,
        height
    )
end

--- @param self ExtendedBoundingBox
--- @param other ExtendedBoundingBox
--- @return boolean
function extended_bounding_box:contains_box(other)
    return self.left_top.x <= other.left_top.x
        and self.left_top.y <= other.left_top.y
        and self.right_bottom.x >= other.right_bottom.x
        and self.right_bottom.y >= other.right_bottom.y
end

--- @param self ExtendedBoundingBox
--- @param other ExtendedBoundingBox
--- @param precision float | nil
--- @return boolean
function extended_bounding_box:intersects(other, precision)
    return self.left_top.x + precision < other.right_bottom.x
        and other.left_top.x + precision < self.right_bottom.x
        and self.left_top.y + precision < other.right_bottom.y
        and other.left_top.y + precision < self.right_bottom.y
end

--- @param self ExtendedBoundingBox
--- @param other ExtendedBoundingBox
--- @param precision integer | nil
--- @return ExtendedBoundingBox | nil
function extended_bounding_box:intersection(other, precision)
	if self:intersects(other, precision) then
        return extended_bounding_box:from_bounding_box({
			left_top = {
				x = math.max(self.left_top.x, other.left_top.x),
				y = math.max(self.left_top.y, other.left_top.y),
			},
			right_bottom = {
				x = math.min(self.right_bottom.x, other.right_bottom.x),
				y = math.min(self.right_bottom.y, other.right_bottom.y),
			}
		})
	end

	return nil
end

--- @param self ExtendedBoundingBox
--- @param just_corners boolean | nil
--- @return string
function extended_bounding_box:to_string(just_corners)
    if just_corners then
        return serpent.line({
            left_top = self.left_top,
            right_bottom = self.right_bottom
        })
    end
    return serpent.line({
        left_top = self.left_top,
        right_bottom = self.right_bottom,
        center = self.center,
        width = self.width,
        height = self.height,
    })
end

--- @param self ExtendedBoundingBox
--- @return ExtendedBoundingBox
function extended_bounding_box:rotate()
    return self:from_values(self.left_top.y, self.left_top.x, self.height, self.width)
end

return extended_bounding_box
