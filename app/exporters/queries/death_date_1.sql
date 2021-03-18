select
    JSON_ARRAYAGG(
        JSON_OBJECT(
            'interviewee_name',
            field_interviewee_name_value,
            'interview_entity_id',
            field_data_field_interviewee_name.entity_id,
            'interview_number',
            field_data_field_interview_number.field_interview_number_value,

            'death_date_1',
            field_death_date_month_year_value
        )
    )
from
    field_data_field_interviewee_name,
    field_data_field_interview_number,

    field_data_field_death_date_month_year target_table

WHERE
    field_data_field_interviewee_name.entity_id =  field_data_field_interview_number.entity_id
AND
    field_data_field_interviewee_name.revision_id = field_data_field_interview_number.revision_id
AND

    field_data_field_interviewee_name.entity_id =  target_table.entity_id
AND
    field_data_field_interviewee_name.revision_id = target_table.revision_id
;