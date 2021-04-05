select
    field_interviewee_name_value as interviewee_name,
    field_data_field_interviewee_name.entity_id as interview_entity_id,
    field_data_field_interview_number.field_interview_number_value as interview_number,
    field_birth_loc_state_select_value as birth_state,
    published.status published
from
    field_data_field_interviewee_name,
    field_data_field_interview_number,
    field_data_field_birth_loc_state_select target_table,
    node published
WHERE
    field_data_field_interviewee_name.entity_id =  field_data_field_interview_number.entity_id
AND
    field_data_field_interviewee_name.revision_id = field_data_field_interview_number.revision_id
AND
    field_data_field_interviewee_name.entity_id =  target_table.entity_id
AND
    field_data_field_interviewee_name.revision_id = target_table.revision_id
AND
    published.nid = field_data_field_interviewee_name.entity_id
-- AND
--     published.status = 1