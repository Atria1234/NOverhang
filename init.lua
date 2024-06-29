NOverhang = {}

NOverhang.mod_name = 'NOverhang'

--- @alias SupportedEntityType
--- | 'accumulator'
--- | 'assembling-machine'
--- | 'beacon'
--- | 'boiler'
--- | 'burner-generator'
--- | 'furnace'
--- | 'generator'
--- | 'lab'
--- | 'mining-drill'
--- | 'reactor'
--- | 'roboport'
--- | 'storage-tank'

--- @type SupportedEntityType[]
NOverhang.entity_types = {
    'accumulator',
    'assembling-machine',
    'beacon',
    'boiler',
    'burner-generator',
    'furnace',
    'generator',
    'lab',
    'mining-drill',
    'reactor',
    'roboport',
    'storage-tank'
}

--- @param entity_type SupportedEntityType
function NOverhang.process_setting_name(entity_type)
    return NOverhang.mod_name..'__process-'..entity_type
end

--- @param entity_type SupportedEntityType
function NOverhang.exclude_setting_name(entity_type)
    return NOverhang.mod_name..'__exclude-'..entity_type
end

--- @param entity_type SupportedEntityType
--- @return boolean
function NOverhang.should_process_entity_type(entity_type)
    local setting = settings.startup[NOverhang.process_setting_name(entity_type)]
    return setting and setting.value
end

--- @param entity_type SupportedEntityType
--- @return { [string]: boolean }
function NOverhang.excluded_entity_names_from_processing(entity_type)
    local value = settings.startup[NOverhang.exclude_setting_name(entity_type)].value

    local entity_names = {}
    for name in string.gmatch(value, '%S+') do
        entity_names[name] = true
    end

    return entity_names
end
