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
