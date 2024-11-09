require('init')
local BoundingBox = require('scripts.bounding-box')
local processing = require('scripts.processing')

--- @param entity_type SupportedEntityType
--- @param properties { [string]: function }
--- @param rotate_bounding_box boolean | nil
local function process_entity_type(entity_type, properties, rotate_bounding_box)
    if NOverhang.should_process_entity_type(entity_type) then
        local exclude = NOverhang.excluded_entity_names_from_processing(entity_type)
        for name, entity in pairs(data.raw[entity_type]) do
            if not exclude[name] and entity.selection_box then
                log('Processing type: "'..entity_type..'", name: "'..name..'"')
                local entity_bounding_box = BoundingBox:from_bounding_box(entity.selection_box)
                if rotate_bounding_box then
                    entity_bounding_box = entity_bounding_box:rotate()
                end

                for property_name, process_function in pairs(properties) do
                    if entity[property_name] then
                        process_function(entity[property_name], entity_bounding_box, entity)
                    end
                end
            end
        end
    end
end

process_entity_type('accumulator', {
    chargable_graphics = processing.process_chargable_graphics
})
process_entity_type('assembling-machine', {
    graphics_set = processing.process_crafting_machine_graphics_set,
    graphics_set_flipped = processing.process_crafting_machine_graphics_set
})
process_entity_type('beacon', {
    animation = processing.process_animation_1,
    base_picture = processing.process_animation_1,
    graphics_set = processing.process_beacon_graphics_set
})
process_entity_type('boiler', {
    pictures = processing.process_boiler_picture_set
})
process_entity_type('burner-generator', {
    animation = processing.process_animation_4,
    idle_animation = processing.process_animation_4
})
process_entity_type('furnace', {
    graphics_set = processing.process_crafting_machine_graphics_set,
    graphics_set_flipped = processing.process_crafting_machine_graphics_set
})
process_entity_type('generator', {
    vertical_animation = processing.process_animation_1,
    vertical_frozen_patch = processing.process_sprite_1
})
process_entity_type('generator', {
    horizontal_animation = processing.process_animation_1,
    horizontal_frozen_patch = processing.process_sprite_1
}, true)
process_entity_type('lab', {
    on_animation = processing.process_animation_1,
    off_animation = processing.process_animation_1,
    frozen_patch = processing.process_sprite_1
})
process_entity_type('mining-drill', {
    graphics_set = processing.process_mining_drill_graphics_set,
    wet_mining_graphics_set = processing.process_mining_drill_graphics_set,
    base_picture = processing.process_sprite_4
})
process_entity_type('reactor', {
    picture = processing.process_sprite_1
})
process_entity_type('roboport', {
    base = processing.process_sprite_1,
    base_patch = processing.process_sprite_1,
    frozen_patch = processing.process_sprite_1,
    base_animation = processing.process_animation_1,
    door_animation_up = processing.process_animation_1,
    door_animation_down = processing.process_animation_1,
    recharging_animation = processing.process_sprite_1
})
process_entity_type('storage-tank', {
    pictures = processing.process_storage_tank
})
