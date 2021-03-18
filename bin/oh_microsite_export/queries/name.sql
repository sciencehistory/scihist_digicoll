select
    JSON_ARRAYAGG(
        JSON_OBJECT(

            'interviewee_name',
            field_interviewee_name_value,

            'interview_entity_id',
            field_data_field_interviewee_name.entity_id,

            'interview_number',
            field_interview_number_value
        )
    )
from
    field_data_field_interviewee_name,
    field_data_field_interview_number accession_number_table
WHERE
    field_data_field_interviewee_name.entity_id =  accession_number_table.entity_id
AND
    field_data_field_interviewee_name.revision_id = accession_number_table.revision_id