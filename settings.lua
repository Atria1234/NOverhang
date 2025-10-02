require('init')

for i, entity_type in ipairs(NOverhang.entity_types) do
	data:extend({
		{
			name = NOverhang.process_setting_name(entity_type),
			type = 'bool-setting',
			setting_type = 'startup',
			default_value = true,
			order = string.format('%02d', i)..'_1'
		},
		{
			name = NOverhang.exclude_setting_name(entity_type),
			type = 'string-setting',
			setting_type = 'startup',
			default_value = '',
			allow_blank = true,
			auto_trim = true,
			order = string.format('%02d', i)..'_2'
		}
	})
end
data:extend({
    {
    name = "NOverhang_toggle_opacity",
    localised_name = "Toggle Opacity",
    type = 'bool-setting',
    setting_type = 'startup',
    default_value = false,
    order = "aaa",
    localised_description = "Rather than crop the top off of the building, make the whole building semi-transparent instead."
    },
    {
    name = "NOverhang_opacity_strength",
    localised_name = "Opacity Strength",
    type = 'int-setting',
    setting_type = 'startup',
    default_value = 80,
    min_value = 0,
    max_value = 100,
    order = "aab",
    localised_description = "What percent opacity should the buildings have? Default is 80% opaque, 20% transparent."
    }
})