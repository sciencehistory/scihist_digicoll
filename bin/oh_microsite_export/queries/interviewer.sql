select
    interviewer_node.nid interviewer_id,
    REPLACE(interviewer_node.title,'Interviewer > ','') interviewer_name,
    field_data_field_interview_number.field_interview_number_value as interview_number,
    oral_history.title oral_history_title,
    interviewer_link.entity_id interview_entity_id
from
    node interviewer_node,
    field_data_field_interviewer interviewer_link,
    node oral_history,
    field_data_field_interview_number
WHERE
    interviewer_node.type = 'interviewer'
AND
    interviewer_link.field_interviewer_nid = interviewer_node.nid
AND
    interviewer_link.bundle = 'oral_history'
AND
    oral_history.nid = interviewer_link.entity_id
AND
    oral_history.vid = interviewer_link.revision_id
AND
    oral_history.nid =  field_data_field_interview_number.entity_id
AND
    oral_history.vid = field_data_field_interview_number.revision_id
ORDER BY
    oral_history.title