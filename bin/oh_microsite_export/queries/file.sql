select
    field_data_field_interviewee_name.entity_id interview_entity_id,
    field_data_field_interview_number.field_interview_number_value interview_number,
    field_interviewee_name_value as interviewee_name,

    field_view_entire_history_pdf_fid as pdf_fid,
    pdf_metadata.filename pdf_filename,
    REPLACE(pdf_metadata.uri,'public://','/sites/default/files/') pdf_url,

    abstract_file.field_pdf_abstract_fid abstract_fid,
    abstract_metadata.filename abstract_filename,
    REPLACE(abstract_metadata.uri,'public://','/sites/default/files/') abstract_url

FROM
    file_managed pdf_metadata,
    file_managed abstract_metadata,
    field_data_field_interview_number,
    field_data_field_interviewee_name
    LEFT JOIN
        field_data_field_view_entire_history_pdf pdf_file
    ON
        field_data_field_interviewee_name.entity_id = pdf_file.entity_id
        AND
        field_data_field_interviewee_name.revision_id = pdf_file.revision_id
    LEFT JOIN
        field_data_field_pdf_abstract abstract_file
    ON
        field_data_field_interviewee_name.entity_id = abstract_file.entity_id
        AND
        field_data_field_interviewee_name.revision_id = abstract_file.revision_id

WHERE
    field_data_field_interviewee_name.entity_id =  field_data_field_interview_number.entity_id
AND
    field_data_field_interviewee_name.revision_id = field_data_field_interview_number.revision_id
AND
     pdf_file.field_view_entire_history_pdf_fid = pdf_metadata.fid
AND
    abstract_file.field_pdf_abstract_fid       =  abstract_metadata.fid
ORDER BY
    field_data_field_interview_number.field_interview_number_value