select
    interviewer_node.nid interviewer_id,
    REPLACE(interviewer_node.title,'Interviewer > ','') interviewer_name,
    interviewer_profile.body_value interviewer_profile
from
    node interviewer_node,
    field_data_body interviewer_profile
WHERE
    interviewer_node.type = 'interviewer'
AND
    interviewer_node.nid = interviewer_profile.entity_id