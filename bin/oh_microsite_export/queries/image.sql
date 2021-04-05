select
    field_data_field_interviewee_name.entity_id interview_entity_id,
    field_data_field_interview_number.field_interview_number_value interview_number,
    field_interviewee_name_value as interviewee_name,
    image_metadata.filename filename,
    REPLACE(image_metadata.uri,'public://','https://oh.sciencehistory.org/sites/default/files/') url,
    image_title.field_file_image_title_text_value title,
    image_alt.field_file_image_alt_text_value alt,
    image_caption.field_image_caption_value caption
    -- ,
    -- image_metadata.status image_published,
    -- image.field_image_fid as image_fid,
    -- published.status published
from
    field_data_field_interviewee_name,
    field_data_field_interview_number,
    field_data_field_image image,
    file_managed image_metadata,
    field_data_field_file_image_title_text  image_title,
    field_data_field_file_image_alt_text    image_alt,
    field_data_field_image_caption          image_caption,
    node published
WHERE
    field_data_field_interviewee_name.entity_id =  field_data_field_interview_number.entity_id
AND
    field_data_field_interviewee_name.revision_id = field_data_field_interview_number.revision_id
AND
    field_data_field_interviewee_name.entity_id = image.entity_id
AND
    field_data_field_interviewee_name.revision_id = image.revision_id
AND
    published.nid = field_data_field_interviewee_name.entity_id
AND
    image.field_image_fid = image_metadata.fid
AND
    image_title.entity_id = image_metadata.fid
AND
    image_alt.entity_id = image_metadata.fid
AND
    field_data_field_interviewee_name.entity_id = image_caption.entity_id
AND
    field_data_field_interviewee_name.revision_id = image_caption.revision_id
-- AND
--     published.status = 1
-- AND
--     image_metadata.status = 1
ORDER BY
    field_data_field_interview_number.field_interview_number_value