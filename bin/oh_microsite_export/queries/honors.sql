select
    JSON_ARRAYAGG(
        JSON_OBJECT(
            'interviewee_name',
            field_interviewee_name_value,
            'interview_entity_id',
            field_data_field_interviewee_name.entity_id,
            'interview_number',
            field_data_field_interview_number.field_interview_number_value,


            'interviewee_honor_description',
            desc_target.field_description_value,
            'interviewee_honor_start_date',
            date_target.field_date_span_value,
            'interviewee_honor_end_date',
            date_target.field_date_span_value2
        )
    )
from
    field_data_field_interviewee_name,
    field_data_field_interview_number,
    field_data_field_interviewee_honors link,
    field_data_field_description desc_target,
    field_data_field_date_span date_target

WHERE
    field_data_field_interviewee_name.entity_id =  field_data_field_interview_number.entity_id
AND
    field_data_field_interviewee_name.revision_id = field_data_field_interview_number.revision_id
AND
    field_data_field_interviewee_name.entity_id =  link.entity_id
AND
    field_data_field_interviewee_name.revision_id = link.revision_id
AND
    link.field_interviewee_honors_value = desc_target.entity_id
AND
    link.field_interviewee_honors_value = date_target.entity_id