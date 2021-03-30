select
    field_interviewee_name_value interviewee_name,
    field_data_field_interviewee_name.entity_id interview_entity_id,
    field_data_field_interview_number.field_interview_number_value interview_number,
    COALESCE (
        LEFT(field_interviewee_birth_date_value, 10),  -- YYY-MM-DD
        LEFT(field_birth_date_month_year_value,   7),  -- YYYY-MM
        LEFT(field_birth_date_year_only_value,    4)   -- YYYY
    ) birth_date
from
    field_data_field_interview_number,
    field_data_field_interviewee_name
LEFT JOIN
    field_data_field_birth_date_month_year target_table_1
    ON
        field_data_field_interviewee_name.entity_id =  target_table_1.entity_id
    AND
        field_data_field_interviewee_name.revision_id =  target_table_1.revision_id
LEFT JOIN
    field_data_field_birth_date_year_only target_table_2
    ON
        field_data_field_interviewee_name.entity_id =  target_table_2.entity_id
    AND
        field_data_field_interviewee_name.revision_id = target_table_2.revision_id
LEFT JOIN
    field_data_field_interviewee_birth_date target_table_3
    ON
        field_data_field_interviewee_name.entity_id =  target_table_3.entity_id
    AND
        field_data_field_interviewee_name.revision_id = target_table_3.revision_id
WHERE
    field_data_field_interviewee_name.entity_id =  field_data_field_interview_number.entity_id
AND
    field_data_field_interviewee_name.revision_id = field_data_field_interview_number.revision_id