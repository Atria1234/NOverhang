local pixel_utils = require('scripts.pixel-utils')
local BoundingBox = require('scripts.bounding-box')

local not_implemented_error_message = 'Not implemented because it wasn\'t encountered so far. Contact mod author with details with name of entity which was processed (visible in Factorio log) and from which mod the entity is.'

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
    if settings.startup["NOverhang_toggle_opacity"].value == false then 
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
    else 
        local intersection_tiles = overhangs(data, entity_bounding_box)
        local alpha = settings.startup["NOverhang_opacity_strength"].value * 0.01

        if intersection_tiles ~= false then
            local t = data.tint
            if t then
                if t[1] then
                    local r, g, b, a = t[1], t[2], t[3], t[4] or 1
                    data.tint = { r = r, g = g, b = b, a = a * alpha }
                else
                    t.a = (t.a or 1) * alpha
                    data.tint = t
                end
            else
                data.tint = { r = 1, g = 1, b = 1, a = alpha }
            end
            return
        end
    end
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
        local sprites = {}
		for layer_index, sprite_sheet in ipairs(data.sheets) do
            local sheet_sprites = process_functions.convert_sprite_n_sheet_to_sprites(sprite_sheet, entity_bounding_box, 4)
            for sprite_index, sprite in ipairs(sheet_sprites) do
                sprites[sprite_index] = sprites[sprite_index] or { layers = {} }
                sprites[sprite_index].layers[layer_index] = sprite
            end
        end
        data.sheets = nil
        data.north = sprites[1]
        data.east = sprites[2] or sprites[1]
        data.south = sprites[3] or sprites[1]
        data.west = sprites[4] or sprites[2] or sprites[1]
	elseif data.sheet then
        local sprites = process_functions.convert_sprite_n_sheet_to_sprites(data.sheet, entity_bounding_box, 4)
        data.sheet = nil
        data.north = sprites[1]
        data.east = sprites[2] or sprites[1]
        data.south = sprites[3] or sprites[1]
        data.west = sprites[4] or sprites[2] or sprites[1]
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

--- https://lua-api.factorio.com/latest/types/Sprite16Way.html
--- @param data data.Sprite8Way
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_sprite_16(data, entity_bounding_box)
	if data.sheets then
        error('Processing Sprite8Way with sheets. '..not_implemented_error_message)
	elseif data.sheet then
        error('Processing Sprite8Way with sheet. '..not_implemented_error_message)
	else
		local directions = {
			'north',
			'north_north_east',
			'north_east',
			'east_north_east',
			'east',
			'east_south_east',
			'south_east',
			'south_south_east',
			'south',
			'south_south_west',
			'south_west',
			'west_south_west',
			'west',
			'west_north_west',
			'north_west',
			'north_north_west'
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
--- @param n integer | nil
--- @return data.Sprite[]
function process_functions.convert_sprite_n_sheet_to_sprites(data, entity_bounding_box, n)
    --- @type data.Sprite[]
    local hr_versions = {}
	if data.hr_version then
        hr_versions = process_functions.convert_sprite_n_sheet_to_sprites(data.hr_version, entity_bounding_box, n)
    end

    local sprites = {}
    for i = 1, data.frames or n or 1 do
        --- @type data.SpriteNWaySheet
        local sheet_copy = table.deepcopy(data)
        sheet_copy.frames = nil

        --- @type data.Sprite
        local sprite = sheet_copy
        sprite.hr_version = hr_versions[i] or nil
        process_sprite_parameters(sprite, math.fmod(i, 2) == 1 and entity_bounding_box or entity_bounding_box:rotate(), i - 1)
        table.insert(sprites, sprite)
    end
    return sprites
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
    local lines_per_file = data.lines_per_file or data.variation_count or 1
    local sprites = {}
    for i = 1, data.variation_count or 1 do
        local row_index = math.floor((i - 1) / line_length)
        local column_index = (i - 1) % line_length

        local file_index = math.floor(row_index / lines_per_file)
        local row_index_in_file = row_index % lines_per_file

        -- Files are structured below each other
        -- file1:
        -- 0 1
        -- 2 3
        -- file2:
        -- 4 5
        -- 6 7

        --- @type data.SpriteSheet
        local sprite_sheet = table.deepcopy(data)
        sprite_sheet.layers = nil
        sprite_sheet.variation_count = nil
        sprite_sheet.repeat_count = nil
        sprite_sheet.line_length = nil
        sprite_sheet.lines_per_file = nil
        sprite_sheet.filenames = nil

        --- @type data.Sprite
        local sprite = sprite_sheet
        sprite.filename = data.filename or data.filenames[file_index + 1]

        process_sprite_parameters(sprite, entity_bounding_box, column_index, row_index_in_file)
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
    error(not_implemented_error_message)
end

-- Animations

--- https://lua-api.factorio.com/latest/types/AnimationParameters.html
--- @param data data.Animation
--- @param entity_bounding_box ExtendedBoundingBox
local function convert_animation_parameters_to_stripes(data, entity_bounding_box)
    local sprite_bounding_box_pixels = BoundingBox:from_sprite_parameters_pixels(data)

    process_sprite_parameters(data, entity_bounding_box)
    local sprite_bounding_box_pixels_2 = BoundingBox:from_sprite_parameters_pixels(data)

    local lines_per_file = data.lines_per_file or data.frame_count or 1
    local line_length = data.line_length or data.frame_count or 1

    local stripes = {}
    for i = 0, (data.frame_count or 1) - 1 do
        local row_index = math.floor(i / line_length)
        local column_index = i % line_length

        local file_index = math.floor(row_index / lines_per_file)
        local row_index_in_file = row_index % lines_per_file

        table.insert(stripes, {
            filename = data.filename or data.filenames[file_index + 1],
            x = sprite_bounding_box_pixels_2.left_top.x + sprite_bounding_box_pixels.width * column_index,
            y = sprite_bounding_box_pixels_2.left_top.y + sprite_bounding_box_pixels.height * row_index_in_file,
            width_in_frames = 1,
            height_in_frames = 1
        })
    end

    data.stripes = stripes
    data.x = nil
    data.y = nil
    data.position = nil
    data.filename = nil
    data.filenames = nil
    data.line_length = nil
    data.lines_per_file = nil
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
            if data.filenames then
                error(not_implemented_error_message)
            end

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
        if data.north_east or data.south_east or data.south_west or data.north_west then
            error(not_implemented_error_message)
        end
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

    if data.filenames or data.lines_per_file then
        error(not_implemented_error_message)
    end

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
    elseif data[1] then
        for _, animation in ipairs(data) do
            process_functions.process_animation_1(animation, entity_bounding_box)
        end
    else
        process_functions.process_animation_1(data, entity_bounding_box)
    end
end

--- https://lua-api.factorio.com/latest/types/RotatedAnimation.html
--- @param data data.RotatedAnimation
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_rotated_animation(data, entity_bounding_box)
    error(not_implemented_error_message)
end

--- https://lua-api.factorio.com/latest/types/RotatedAnimation4Way.html
--- @param data data.RotatedAnimation4Way
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_rotated_animation_4(data, entity_bounding_box)
    if data.north then
        if data.north_east or data.south_east or data.south_west or data.north_west then
            error(not_implemented_error_message)
        end
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

-- Graphic sets

--- https://lua-api.factorio.com/latest/types/BeaconGraphicsSet.html
--- @param data data.BeaconGraphicsSet
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_beacon_graphics_set(data, entity_bounding_box)
    if data.animation_list then
        for _, animation_element in ipairs(data.animation_list) do
            process_functions.process_animation_element(animation_element, entity_bounding_box)
        end
    end
    if data.frozen_patch then
        process_functions.process_sprite_1(data.frozen_patch, entity_bounding_box)
    end
end

--- https://lua-api.factorio.com/latest/prototypes/BoilerPrototype.html#pictures
--- @param data data.BoilerPictureSet
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_boiler_picture_set(data, entity_bounding_box)
    local directions = {
        'north',
        'south'
    }
    for _, direction in ipairs(directions) do
        if data[direction] then
            process_functions.process_boiler_pictures(data[direction], entity_bounding_box)
        end
    end

    directions = {
        'east',
        'west'
    }
    for _, direction in ipairs(directions) do
        if data[direction] then
            process_functions.process_boiler_pictures(data[direction], entity_bounding_box:rotate())
        end
    end
end

--- https://lua-api.factorio.com/latest/types/BoilerPictures.html
--- @param data data.BoilerPictures
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_boiler_pictures(data, entity_bounding_box)
    process_functions.process_animation_1(data.structure, entity_bounding_box)
    if data.fire then
        process_functions.process_animation_1(data.fire, entity_bounding_box)
    end
    if data.fire_glow then
        process_functions.process_animation_1(data.fire_glow, entity_bounding_box)
    end
end

--- https://lua-api.factorio.com/latest/types/ChargableGraphics.html
--- @param data data.ChargableGraphics
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_chargable_graphics(data, entity_bounding_box)
    if data.picture then
        process_functions.process_sprite_1(data.picture, entity_bounding_box)
    end
    if data.charge_animation then
        process_functions.process_animation_1(data.charge_animation, entity_bounding_box)
    end
    if data.discharge_animation then
        process_functions.process_animation_1(data.discharge_animation, entity_bounding_box)
    end
end

--- https://lua-api.factorio.com/latest/types/CraftingMachineGraphicsSet.html
--- @param data data.CraftingMachineGraphicsSet
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_crafting_machine_graphics_set(data, entity_bounding_box)
    if data.frozen_patch then
        process_functions.process_sprite_4(data.frozen_patch, entity_bounding_box)
    end
    process_functions.process_working_visualisations(data, entity_bounding_box)
end

--- https://lua-api.factorio.com/latest/types/MiningDrillGraphicsSet.html
--- @param data data.MiningDrillGraphicsSet
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_mining_drill_graphics_set(data, entity_bounding_box)
    if data.frozen_patch then
        process_functions.process_sprite_4(data.frozen_patch, entity_bounding_box)
    end
    process_functions.process_working_visualisations(data, entity_bounding_box)
end

--- https://lua-api.factorio.com/latest/prototypes/StorageTankPrototype.html#pictures
--- @param data data.StorageTankPictures
--- @param entity_bounding_box ExtendedBoundingBox
--- @param entity data.StorageTankPrototype
function process_functions.process_storage_tank(data, entity_bounding_box, entity)
    if data.picture then
        process_functions.process_sprite_4(data.picture, entity_bounding_box)
    end
    if data.frozen_patch then
        process_functions.process_sprite_4(data.frozen_patch, entity_bounding_box)
    end
    local window_bounding_box = BoundingBox:from_bounding_box(entity.window_bounding_box)
    if data.window_background then
        process_functions.process_sprite_1(data.window_background, window_bounding_box)
    end
    if data.fluid_background then
        process_functions.process_sprite_1(data.fluid_background, window_bounding_box)
    end
    if data.flow_sprite then
        process_functions.process_sprite_1(data.flow_sprite, window_bounding_box)
    end
    if data.gas_flow then
        process_functions.process_animation_1(data.gas_flow, window_bounding_box)
    end
end

--- https://lua-api.factorio.com/latest/types/WorkingVisualisations.html
--- @param data data.WorkingVisualisations
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_working_visualisations(data, entity_bounding_box)
    if data.animation then
        process_functions.process_animation_4(data.animation, entity_bounding_box)
    end
    if data.idle_animation then
        process_functions.process_animation_4(data.idle_animation, entity_bounding_box)
    end
    if data.working_visualisations then
        for _, visualisation in ipairs(data.working_visualisations) do
            process_functions.process_working_visualisation(visualisation, entity_bounding_box)
        end
    end
end

--- https://lua-api.factorio.com/latest/types/WorkingVisualisation.html
--- @param data data.WorkingVisualisation
--- @param entity_bounding_box ExtendedBoundingBox
function process_functions.process_working_visualisation(data, entity_bounding_box)
    local directions = {
        'north',
        'west',
        'south',
        'east'
    }

    for _, direction in ipairs(directions) do
        local animation = data.animation or data[direction..'_animation']
        if animation then
            local position = data[direction..'_position'] or {0, 0}
            move_animation(animation, position)
            process_functions.process_animation_1(animation, entity_bounding_box)
            position = {-(position[1] or position.x), -(position[2] or position.y)}
            move_animation(animation, position)
        end
    end
end

--- @param animation data.Animation
--- @param shift Vector
function move_animation(animation, shift)
    if animation.layers then
        for _, layer in ipairs(animation.layers) do
            layer.shift = layer.shift or {0, 0}
            layer.shift = {
                (layer.shift[1] or layer.shift.x) + (shift[1] or shift.x),
                (layer.shift[2] or layer.shift.y) + (shift[2] or shift.y)
            }
        end
    else
        if animation.hr_version then
            move_animation(animation.hr_version, shift)
        end
        animation.shift = animation.shift or {0, 0}
        animation.shift = {
            (animation.shift[1] or animation.shift.x) + (shift[1] or shift.x),
            (animation.shift[2] or animation.shift.y) + (shift[2] or shift.y)
        }
    end
end

return process_functions
