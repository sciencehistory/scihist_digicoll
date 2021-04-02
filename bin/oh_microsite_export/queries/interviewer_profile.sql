SELECT
    interviewer_node.nid interviewer_id,
    REPLACE(interviewer_node.title,'Interviewer > ','') interviewer_name,
    interviewer_profile.body_value interviewer_profile
FROM
    node interviewer_node
LEFT JOIN field_data_body interviewer_profile
    ON interviewer_node.nid = interviewer_profile.entity_id

WHERE
    interviewer_node.type = 'interviewer'