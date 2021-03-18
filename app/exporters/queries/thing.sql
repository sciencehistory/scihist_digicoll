select

    -- OK let's add interviewee birth PROVINCE:


    JSON_OBJECT(
        'interviewee_name',
        field_interviewee_name_value,

        'interview_entity_id',
        field_data_field_interviewee_name.entity_id,

        'interview_number',
        field_interview_number_value,

        'birth_city',
        field_interviewee_birth_city_value,

        'birth_country',
        field_birth_loc_country_select_value,

        'birth_date_1',
        field_birth_date_month_year_value,

        'birth_date_2',
        field_birth_date_year_only_value # ,

        --  select * from field_data_field_interviewee_name,
        -- field_data_field_birth_loc_prov_select where field_data_field_interviewee_name.entity_id = field_data_field_birth_loc_prov_select.entity_id  LIMIT 3;

        -- 'birth_province',
        -- field_birth_loc_prov_select_value


        ) as 'json_values'
from
    field_data_field_interviewee_name,
    field_data_field_interview_number accession_number_table,
    field_data_field_interviewee_birth_city,
    field_data_field_birth_loc_country_select,

    field_data_field_birth_date_month_year,
    field_data_field_birth_date_year_only#,

    -- field_data_field_birth_loc_prov_select

WHERE

    field_data_field_interviewee_name.entity_id = field_data_field_interviewee_birth_city.entity_id
AND
    field_data_field_interviewee_name.revision_id = field_data_field_interviewee_birth_city.revision_id
AND
    field_data_field_interviewee_name.entity_id = field_data_field_birth_loc_country_select.entity_id
AND
    field_data_field_interviewee_name.revision_id = field_data_field_birth_loc_country_select.revision_id
AND
    field_data_field_interviewee_name.entity_id =  accession_number_table.entity_id
AND
    field_data_field_interviewee_name.revision_id = accession_number_table.revision_id
AND
    field_data_field_interviewee_name.entity_id =  field_data_field_birth_date_month_year.entity_id
AND
    field_data_field_interviewee_name.revision_id = field_data_field_birth_date_month_year.revision_id
AND
    field_data_field_interviewee_name.entity_id =  field_data_field_birth_date_year_only.entity_id
AND
    field_data_field_interviewee_name.revision_id = field_data_field_birth_date_year_only.revision_id


        --  select * from field_data_field_interviewee_name,
        -- field_data_field_birth_loc_prov_select where field_data_field_interviewee_name.entity_id = field_data_field_birth_loc_prov_select.entity_id  LIMIT 3;


-- AND
--     field_data_field_interviewee_name.entity_id =  field_data_field_birth_loc_prov_select.entity_id
-- AND
--     field_data_field_interviewee_name.revision_id = field_data_field_birth_loc_prov_select.revision_id


AND
    field_birth_loc_country_select_value != 'US'
LIMIT 3 \G
