local pixel_utils = require('scripts.pixel-utils')
local BoundingBox = require('scripts.bounding-box')

--- @param data data.SpriteParameters
--- @param entity_bounding_box ExtendedBoundingBox
--- @return ExtendedBoundingBox | nil | false
local function overhangs(data, entity_bounding_box)
	local sprite_bounding_box = BoundingBox:from_sprite_parameters_tiles(data)

	if data.draw_as_shadow or entity_bounding_box:contains_box(sprite_bounding_box) then
		return false
	end

	return entity_bounding_box:intersection(sprite_bounding_box, (data.scale or 1) / 32)
end

local function clear_table(table)
    for key, _ in pairs(table) do
        table[key] = nil
    end
end

---@param table any
---@param replace_with any
local function replace_table_content(table, replace_with)
    clear_table(table)
    for key, value in pairs(replace_with) do
        table[key] = value
    end
end

--- Process functions

local process_functions = {}

--- https://lua-api.factorio.com/latest/types/SpriteParameters.html
--- @param data data.SpriteParameters
--- @param entity_bounding_box ExtendedBoundingBox
--- @param index_x integer | nil
--- @param index_y integer | nil
local function process_sprite_parameters(data, entity_bounding_box, index_x, index_y)
	local sprite_bounding_box_pixels = BoundingBox:from_sprite_parameters_pixels(data)
	local sprite_bounding_box_tiles = BoundingBox:from_sprite_parameters_tiles(data)
	local intersection_tiles = overhangs(data, entity_bounding_box)

	if intersection_tiles == false then
		return
	end

    if intersection_tiles == nil then
        data.tint = {0, 0, 0, 0}
        return
    end

    data.position = {
        sprite_bounding_box_pixels.left_top.x +
        pixel_utils.tiles_to_pixels(intersection_tiles.left_top.x - sprite_bounding_box_tiles.left_top.x, data.scale) +
        (index_x or 0) * sprite_bounding_box_pixels.width,

        sprite_bounding_box_pixels.left_top.y +
        pixel_utils.tiles_to_pixels(intersection_tiles.left_top.y - sprite_bounding_box_tiles.left_top.y, data.scale) +
        (index_y or 0) * sprite_bounding_box_pixels.height
    }
    data.x = nil
    data.y = nil

    data.size = {
        pixel_utils.tiles_to_pixels(intersection_tiles.width, data.scale),
        pixel_utils.tiles_to_pixels(intersection_tiles.height, data.scale)
    }
    data.width = nil
    data.height = nil

    data.shift = intersection_tiles.center
end

--- https://lua-api.factorio.com/latest/types/Sprite.html
--- @param data data.Sprite
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_sprite_1(data, entity_bounding_box)
	if data.layers then
		for _, layer in ipairs(data.layers) do
			process_functions.process_sprite_1(layer, entity_bounding_box)
		end
    else
        if data.hr_version then
            process_functions.process_sprite_1(data.hr_version, entity_bounding_box)
        end

        process_sprite_parameters(data, entity_bounding_box)
	end
end

--- https://lua-api.factorio.com/latest/types/Sprite4Way.html
--- @param data data.Sprite4Way
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_sprite_4(data, entity_bounding_box)
	if data.sheets then
		for _, sprite_sheet in ipairs(data.sheets) do
			process_functions.process_sprite_n_sheet(sprite_sheet, entity_bounding_box, 4)
		end
	elseif data.sheet then
        if data.sheet.frames ~= 4 then
            log('Not 4 frames: '..(data.sheet.frames or 'nil'))
        end
		process_functions.process_sprite_n_sheet(data.sheet, entity_bounding_box, 4)
    elseif data.filename or data.layers then
        process_functions.process_sprite_1(data, entity_bounding_box)
    else
		local directions = {
			'north',
			'south'
		}
		for _, direction in ipairs(directions) do
			if data[direction] then
				process_functions.process_sprite_1(data[direction], entity_bounding_box)
			end
		end

		directions = {
			'east',
			'west'
		}
		for _, direction in ipairs(directions) do
			if data[direction] then
				process_functions.process_sprite_1(data[direction], entity_bounding_box:rotate())
			end
		end
	end
end

--- https://lua-api.factorio.com/latest/types/Sprite8Way.html
--- @param data data.Sprite8Way
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_sprite_8(data, entity_bounding_box)
	if data.sheets then
		for _, sprite_sheet in ipairs(data.sheets) do
			process_functions.process_sprite_n_sheet(sprite_sheet, entity_bounding_box, 8)
		end
	elseif data.sheet then
        if data.sheet.frames ~= 8 then
            log('Not 8 frames: '..(data.sheet.frames or 'nil'))
        end
		process_functions.process_sprite_n_sheet(data.sheet, entity_bounding_box, 8)
	else
		local directions = {
			'north',
			'north_east',
			'east',
			'south_east',
			'south',
			'south_west',
			'west',
			'north_west'
		}
		for _, direction in ipairs(directions) do
			if data[direction] then
				process_functions.process_sprite_1(data[direction], entity_bounding_box)
			end
		end
	end
end

--- https://lua-api.factorio.com/latest/types/SpriteNWaySheet.html
--- @param data data.SpriteNWaySheet
--- @param entity_bounding_box ExtendedBoundingBox
--- @param n integer
function process_functions.process_sprite_n_sheet(data, entity_bounding_box, n)
	if data.hr_version then
        process_functions.process_sprite_n_sheet(data.hr_version, entity_bounding_box, n)
    end

    for i = 1, data.frames or n do
        -- TODO convert to sheets with single frame, and test
    end
    process_sprite_parameters(data, entity_bounding_box)
end

--- https://lua-api.factorio.com/latest/types/SpriteSheet.html
--- @param data data.SpriteSheet
--- @param entity_bounding_box ExtendedBoundingBox
--- @return data.Sprite[]
local function convert_sprite_sheet_to_sprite_array(data, entity_bounding_box)
    if data.layers then
        local sprites = {}
        for _, layer in ipairs(data.layers) do
            local layer_sprites = convert_sprite_sheet_to_sprite_array(layer, entity_bounding_box)
            for i, sprite in ipairs(layer_sprites) do
                sprites[i] = sprites[i] or {layers = {}}
                table.insert(sprites[i].layers, sprite)
            end
        end

        return sprites
    end

    local hr_sprites = {}
    if data.hr_version then
        hr_sprites = convert_sprite_sheet_to_sprite_array(data.hr_version, entity_bounding_box)
    end

    local line_length = data.line_length or data.variation_count or 1
    local sprites = {}
    for i = 1, data.variation_count or 1 do
        --- @type data.SpriteSheet
        local sprite_sheet = table.deepcopy(data)
        sprite_sheet.layers = nil
        sprite_sheet.variation_count = nil
        sprite_sheet.repeat_count = nil
        sprite_sheet.line_length = nil

        --- @type data.Sprite
        local sprite = sprite_sheet

        process_sprite_parameters(sprite, entity_bounding_box, (i - 1) % line_length, math.floor((i - 1) / line_length))
        sprite.hr_version = data.hr_version and hr_sprites[i] or nil

        for j = 1, data.repeat_count or 1 do
            sprites[(j - 1) * (data.variation_count or 1) + i] = table.deepcopy(sprite)
        end
    end

    return sprites
end

--- https://lua-api.factorio.com/latest/types/SpriteVariations.html
--- @param data data.SpriteVariations
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_sprite_variantions(data, entity_bounding_box)
    if data[1] then
        for _, sprite in ipairs(data) do
            process_functions.process_sprite_1(sprite, entity_bounding_box)
        end
    else
        local sprites = convert_sprite_sheet_to_sprite_array(data.sheet or data, entity_bounding_box)
        replace_table_content(data, sprites)
    end
end


-- https://lua-api.factorio.com/latest/types/RotatedSprite.html
--- @param data data.SpriteVariations
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_rotated_sprite(data, entity_bounding_box)
    error('Not implemented')
end

-- Animations

--- https://lua-api.factorio.com/latest/types/AnimationParameters.html
--- @param data data.Animation
--- @param entity_bounding_box ExtendedBoundingBox
local function convert_animation_parameters_to_stripes(data, entity_bounding_box)
    local sprite_bounding_box_pixels = BoundingBox:from_sprite_parameters_pixels(data)

    process_sprite_parameters(data, entity_bounding_box)
    local sprite_bounding_box_pixels_2 = BoundingBox:from_sprite_parameters_pixels(data)

    data.line_length = data.line_length or data.frame_count or 1

    local stripes = {}
    for i = 0, (data.frame_count or 1) - 1 do
        table.insert(stripes, {
            filename = data.filename,
            x = sprite_bounding_box_pixels_2.left_top.x + sprite_bounding_box_pixels.width * (i % data.line_length),
            y = sprite_bounding_box_pixels_2.left_top.y + sprite_bounding_box_pixels.height * math.floor(i / data.line_length),
            width_in_frames = 1,
            height_in_frames = 1
        })
    end

    data.stripes = stripes
    data.x = nil
    data.y = nil
    data.position = nil
    data.filename = nil
    data.line_length = nil
end

--- https://lua-api.factorio.com/latest/types/Stripe.html
--- @param data data.Animation
--- @param stripe_index integer
--- @param entity_bounding_box ExtendedBoundingBox
local function process_stripe(data, stripe_index, entity_bounding_box)
    --- @type data.Stripe
    local stripe = data.stripes[stripe_index]

    --- @type data.SpriteParameters
    local data_copy = {
        filename = stripe.filename,
        size = data.size,
        x = stripe.x,
        y = stripe.y,
        width = data.width,
        height = data.height,
        scale = data.scale,
        shift = data.shift
    }
    local old_bounding_box = BoundingBox:from_sprite_parameters_pixels(data)

    process_sprite_parameters(data_copy, entity_bounding_box)
    local new_bounding_box = BoundingBox:from_sprite_parameters_pixels(data_copy)

    local stripes = {}
    for j = 1, stripe.height_in_frames do
        for i = 1, stripe.width_in_frames do
            table.insert(stripes, {
                filename = stripe.filename,
                x = new_bounding_box.left_top.x + old_bounding_box.width * (i - 1),
                y = new_bounding_box.left_top.y + old_bounding_box.height * (j - 1),
                width_in_frames = 1,
                height_in_frames = 1
            })
        end
    end

    return stripes
end

--- https://lua-api.factorio.com/latest/types/Animation.html
--- @param data data.Animation
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_animation_1(data, entity_bounding_box)
	if data.layers then
		for _, layer in ipairs(data.layers) do
			process_functions.process_animation_1(layer, entity_bounding_box)
		end
    else
        if data.hr_version then
            process_functions.process_animation_1(data.hr_version, entity_bounding_box)
        end

        if data.stripes then
            local stripes = {}
            for stripe_index, _ in ipairs(data.stripes) do
                for _, new_stripe in ipairs(process_stripe(data, stripe_index, entity_bounding_box)) do
                    table.insert(stripes, new_stripe)
                end
            end

            --- @type data.SpriteParameters
            local data_copy = {
                filename = data.stripes[1].filename,
                size = data.size,
                x = data.stripes[1].x,
                y = data.stripes[1].y,
                width = data.width,
                height = data.height,
                scale = data.scale,
                shift = data.shift
            }
            process_sprite_parameters(data_copy, entity_bounding_box)

            data.size = data_copy.size
            data.width = data_copy.width
            data.height = data_copy.height
            data.shift = data_copy.shift
            data.stripes = stripes
        else
            convert_animation_parameters_to_stripes(data, entity_bounding_box)
        end
    end
end

--- https://lua-api.factorio.com/latest/types/Animation4Way.html
--- @param data data.Animation4Way
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_animation_4(data, entity_bounding_box)
    if data.north then
        local directions = {
            'north',
            'south'
        }
        for _, direction in ipairs(directions) do
            if data[direction] then
                process_functions.process_animation_1(data[direction], entity_bounding_box)
            end
        end

        directions = {
            'east',
            'west'
        }
        for _, direction in ipairs(directions) do
            if data[direction] then
                process_functions.process_animation_1(data[direction], entity_bounding_box:rotate())
            end
        end
    else
        process_functions.process_animation_1(data, entity_bounding_box)
    end
end

--- https://lua-api.factorio.com/latest/types/AnimationSheet.html
--- @param data data.AnimationSheet
--- @param entity_bounding_box ExtendedBoundingBox
--- @return data.Animation[]
local function convert_animation_sheet_to_animation_array(data, entity_bounding_box)
    local hr_versions = {}
	if data.hr_version then
        hr_versions = convert_animation_sheet_to_animation_array(data.hr_version, entity_bounding_box)
    end

    local animation_bounding_box_pixels = BoundingBox:from_sprite_parameters_pixels(data)

    local animations = {}
    for i = 1, data.variation_count do
        local data_copy = table.deepcopy(data)
        data_copy.hr_version = nil
        data_copy.variation_count = nil
        data_copy.line_length = data_copy.frame_count

        --- @type data.Animation
        local animation = data_copy
        animation.y = animation_bounding_box_pixels.left_top.y + (i - 1) * animation_bounding_box_pixels.height
        process_functions.process_animation_1(animation, entity_bounding_box)

        animation.hr_version = hr_versions[i]
        table.insert(animations, animation)
    end

    return animations
end

--- https://lua-api.factorio.com/latest/types/AnimationVariations.html
--- @param data data.AnimationVariations
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_animation_variation(data, entity_bounding_box)
	if data.sheet then
        replace_table_content(data, convert_animation_sheet_to_animation_array(data.sheet, entity_bounding_box))
    elseif data.sheets then
        local animations = {}
        for _, sheet in ipairs(data.sheets) do
            for _, animation in ipairs(convert_animation_sheet_to_animation_array(sheet, entity_bounding_box)) do
                table.insert(animations, animation)
            end
        end

        replace_table_content(data, animations)
    else
        if data[1] then
            for _, animation in ipairs(data) do
                process_functions.process_animation_1(animation, entity_bounding_box)
            end
        else
            process_functions.process_animation_1(data, entity_bounding_box)
        end
    end
end

--- https://lua-api.factorio.com/latest/types/RotatedAnimation.html
--- @param data data.RotatedAnimation
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_rotated_animation(data, entity_bounding_box)
    error('Not implemented')
end

--- https://lua-api.factorio.com/latest/types/RotatedAnimation4Way.html
--- @param data data.RotatedAnimation4Way
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_rotated_animation_4(data, entity_bounding_box)
    if data.north then
        local directions = {
            'north',
            'south'
        }
        for _, direction in ipairs(directions) do
            if data[direction] then
                process_functions.process_rotated_animation(data[direction], entity_bounding_box)
            end
        end

        directions = {
            'east',
            'west'
        }
        for _, direction in ipairs(directions) do
            if data[direction] then
                process_functions.process_rotated_animation(data[direction], entity_bounding_box:rotate())
            end
        end
    else
        process_functions.process_rotated_animation(data, entity_bounding_box)
    end
end

--- https://lua-api.factorio.com/latest/types/RotatedAnimationVariations.html
--- @param data data.RotatedAnimationVariations
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_rotated_animation_variations(data, entity_bounding_box)
    if data[1] then
        for _, rotated_animation in ipairs(data) do
            process_functions.process_rotated_animation(rotated_animation, entity_bounding_box)
        end
    else
        process_functions.process_rotated_animation(data, entity_bounding_box)
    end
end

--- https://lua-api.factorio.com/latest/types/AnimationElement.html
--- @param data data.AnimationElement
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_animation_element(data, entity_bounding_box)
	if data.animation then
        process_functions.process_animation_1(data.animation, entity_bounding_box)
    end
end

--- https://lua-api.factorio.com/latest/types/BeamAnimationSet.html
--- @param data data.BeamAnimationSet
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_beam_animation_set(data, entity_bounding_box)
    local directions = {
        'start',
        'ending',
        'head',
        'tail'
    }
    for _, direction in ipairs(directions) do
        if data[direction] then
            process_functions.process_animation_1(data[direction], entity_bounding_box)
        end
    end

    if data.body then
        process_functions.process_animation_variation(data.body, entity_bounding_box)
    end
end

--- https://lua-api.factorio.com/latest/prototypes/BoilerPrototype.html#structure
--- https://lua-api.factorio.com/latest/prototypes/BoilerPrototype.html#fire
--- https://lua-api.factorio.com/latest/prototypes/BoilerPrototype.html#fire_glow
--- @param data data.BoilerStructure | data.BoilerFire | data.BoilerFireGlow
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_boiler(data, entity_bounding_box)
    local directions = {
        'east',
        'south'
    }
    for _, direction in ipairs(directions) do
        if data[direction] then
            process_functions.process_animation_1(data[direction], entity_bounding_box)
        end
    end

    directions = {
        'east',
        'west'
    }
    for _, direction in ipairs(directions) do
        if data[direction] then
            process_functions.process_animation_1(data[direction], entity_bounding_box:rotate())
        end
    end
end

--- https://lua-api.factorio.com/latest/types/BeaconGraphicsSet.html
--- @param data data.BeaconGraphicsSet
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_beacon_graphics_set(data, entity_bounding_box)
    if data.animation_list then
        for _, animation_element in ipairs(data.animation_list) do
            process_functions.process_animation_element(animation_element, entity_bounding_box)
        end
    end
end

--- https://lua-api.factorio.com/latest/types/CharacterArmorAnimation.html
--- @param data data.CharacterArmorAnimation
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_character_armor_animation(data, entity_bounding_box)
    local directions = {
        'idle',
        'idle_with_gun',
        'running',
        'running_with_gun',
        'mining_with_tool',
        'flipped_shadow_running_with_gun'
    }
    for _, direction in ipairs(directions) do
        if data[direction] then
            process_functions.process_rotated_animation(data[direction], entity_bounding_box)
        end
    end
end

--- https://lua-api.factorio.com/latest/types/MiningDrillGraphicsSet.html
--- @param data data.MiningDrillGraphicsSet
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_mining_drill_graphics_set(data, entity_bounding_box)
	if data.animation then
        process_functions.process_animation_4(data.animation, entity_bounding_box)
    end

	if data.idle_animation then
        process_functions.process_animation_4(data.idle_animation, entity_bounding_box)
    end

    if data.working_visualisations then
        process_functions.process_working_visualisations(data.working_visualisations, entity_bounding_box)
    end
end

--- https://lua-api.factorio.com/latest/types/PumpConnectorGraphicsAnimation.html
--- @param data data.PumpConnectorGraphicsAnimation
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_pump_connector_graphics_animation(data, entity_bounding_box)
    local directions = {
        'startup_base',
        'startup_top',
        'startup_shadow',
        'connector',
        'connector_shadow'
    }
    for _, direction in ipairs(directions) do
        if data[direction] then
            process_functions.process_animation_1(data[direction], entity_bounding_box)
        end
    end
end

--- https://lua-api.factorio.com/latest/types/SpiderVehicleGraphicsSet.html
--- @param data data.SpiderVehicleGraphicsSet
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_spider_vehicle_graphics_set(data, entity_bounding_box)
    local directions = {
        'base_animation',
        'shadow_base_animation',
        'animation',
        'shadow_animation'
    }
    for _, direction in ipairs(directions) do
        if data[direction] then
            process_functions.process_rotated_animation(data[direction], entity_bounding_box)
        end
    end

    directions = {
        'autopilot_destination_on_map_visualisation',
        'autopilot_destination_queue_on_map_visualisation',
        'autopilot_destination_visualisation',
        'autopilot_destination_queue_visualisation'
    }
    for _, direction in ipairs(directions) do
        if data[direction] then
            process_functions.process_animation_1(data[direction], entity_bounding_box)
        end
    end
end

--- https://lua-api.factorio.com/latest/prototypes/StorageTankPrototype.html#pictures
--- @param data data.StorageTankPictures
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_storage_tank(data, entity_bounding_box)
    process_functions.process_sprite_4(data.picture, entity_bounding_box)
end

--- https://lua-api.factorio.com/latest/types/TransportBeltAnimationSet.html
--- https://lua-api.factorio.com/latest/types/TransportBeltAnimationSetWithCorners.html
--- @param data data.TransportBeltAnimationSet
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_transport_belt_animation_set(data, entity_bounding_box)
    process_functions.process_rotated_animation(data.animation_set, entity_bounding_box)
    if data.ending_patch then
        process_functions.process_sprite_4(data.ending_patch, entity_bounding_box)
    end
end

--- https://lua-api.factorio.com/latest/types/WorkingVisualisation.html
--- @param data data.WorkingVisualisation
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_working_visualisation(data, entity_bounding_box)
    -- TODO mozna orotovat bounding box
    local directions = {
        'north',
        'west',
        'south',
        'east'
    }

    for _, direction in ipairs(directions) do
        local animation = data[direction..'_animation'] or data.animation
        if animation then
            local position = data[direction..'_position'] or {0, 0}
            animation.shift = animation.shift or {0, 0}
            animation.shift = {
                (animation.shift[1] or animation.shift.x or 0) + (position[1] or position.x or 0),
                (animation.shift[2] or animation.shift.y or 0) + (position[2] or position.y or 0)
            }
            process_functions.process_animation_1(animation, entity_bounding_box)
            animation.shift = {
                (animation.shift[1] or animation.shift.x) - (position[1] or position.x),
                (animation.shift[2] or animation.shift.y) - (position[2] or position.y)
            }
        end
    end
end

--- https://lua-api.factorio.com/latest/types/WorkingVisualisation.html
--- @param data data.WorkingVisualisation[]
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_working_visualisations(data, entity_bounding_box)
    for _, visualisation in ipairs(data) do
        process_functions.process_working_visualisation(visualisation, entity_bounding_box)
    end
end

return process_functions
