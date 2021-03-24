select
    field_interviewee_name_value as interviewee_name,
    field_data_field_interviewee_name.entity_id as interview_entity_id,
    field_data_field_interview_number.field_interview_number_value as interview_number,
    field_interviewee_birth_city_value as birth_city
from
    field_data_field_interviewee_name,
    field_data_field_interview_number,
    field_data_field_interviewee_birth_city target_table
WHERE
    field_data_field_interviewee_name.entity_id =  field_data_field_interview_number.entity_id
AND
    field_data_field_interviewee_name.revision_id = field_data_field_interview_number.revision_id
AND
    field_data_field_interviewee_name.entity_id = target_table.entity_id
AND
    field_data_field_interviewee_name.revision_id = target_table.revision_id
;