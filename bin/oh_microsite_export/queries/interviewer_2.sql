select
    interviewer_node.nid interviewer_id,
    REPLACE(interviewer_node.title,'Interviewer > ','') interviewer_name,
    field_data_field_interview_number.field_interview_number_value as interview_number,
    -- interviewer_link.entity_id session_id,
    -- sessions.entity_id session_node_number,
    oral_history.title oral_history_title
from
    node interviewer_node,
    field_data_field_interviewer interviewer_link,
    field_data_field_interview_sessions sessions,
    node oral_history,
    field_data_field_interview_number
WHERE
    interviewer_node.type = 'interviewer'
AND
    interviewer_link.field_interviewer_nid = interviewer_node.nid
AND
    interviewer_link.bundle = 'field_interview_sessions'
AND
    interviewer_link.entity_id = sessions.field_interview_sessions_value
AND
    interviewer_link.revision_id = sessions.field_interview_sessions_revision_id
AND
    oral_history.nid = sessions.entity_id
AND
    oral_history.vid = sessions.revision_id
AND
    oral_history.nid =  field_data_field_interview_number.entity_id
AND
    oral_history.vid = field_data_field_interview_number.revision_id
ORDER BY
    oral_history.title