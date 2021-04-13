select
    field_interviewee_name_value interviewee_name,
    field_data_field_interviewee_name.entity_id interview_entity_id,
    CONCAT("https://oh.sciencehistory.org/node/", field_data_field_interviewee_name.entity_id) source_url,
    field_interview_number_value interview_number,
    published.status published
from
    field_data_field_interviewee_name,
    field_data_field_interview_number accession_number_table,
    node published
WHERE
    field_data_field_interviewee_name.entity_id =  accession_number_table.entity_id
AND
    field_data_field_interviewee_name.revision_id = accession_number_table.revision_id
AND
    published.nid = field_data_field_interviewee_name.entity_id