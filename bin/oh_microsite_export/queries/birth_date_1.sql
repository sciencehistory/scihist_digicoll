select
    field_interviewee_name_value interviewee_name,
    field_data_field_interviewee_name.entity_id interview_entity_id,
    field_data_field_interview_number.field_interview_number_value interview_number,
    field_birth_date_month_year_value birth_date_1
from
    field_data_field_interviewee_name,
    field_data_field_interview_number,
    field_data_field_birth_date_month_year target_table
WHERE
    field_data_field_interviewee_name.entity_id =  field_data_field_interview_number.entity_id
AND
    field_data_field_interviewee_name.revision_id = field_data_field_interview_number.revision_id
AND
    field_data_field_interviewee_name.entity_id =  target_table.entity_id
AND
    field_data_field_interviewee_name.revision_id = target_table.revision_id
;