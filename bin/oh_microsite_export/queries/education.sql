select
    field_interviewee_name_value interviewee_name,
    field_data_field_interviewee_name.entity_id interview_entity_id,
    field_data_field_interview_number.field_interview_number_value interview_number,
    link.field_interviewee_education_value education_id,
    discipline_target.field_discipline_value discipline,
    degree_target.field_degree_value degree,
    date_target.field_year_value date,
    school_link.field_job_exp_institution_ref_nid school_id,
    school.title school_name,
    published.status published
from
    field_data_field_interviewee_name,
    field_data_field_interview_number,
    field_data_field_interviewee_education          link,
    field_data_field_discipline                     discipline_target,
    field_data_field_degree                         degree_target,
    field_data_field_year                           date_target,
    field_data_field_job_exp_institution_ref        school_link,
    node                                            school,
    node published
WHERE
    field_data_field_interviewee_name.entity_id    = field_data_field_interview_number.entity_id
AND
    field_data_field_interviewee_name.revision_id  = field_data_field_interview_number.revision_id
AND
    field_data_field_interviewee_name.entity_id    = link.entity_id
AND
    field_data_field_interviewee_name.revision_id  = link.revision_id
AND
    link.field_interviewee_education_value         = discipline_target.entity_id
AND
    link.field_interviewee_education_revision_id   = discipline_target.revision_id
AND
    link.field_interviewee_education_value         = degree_target.entity_id
AND
    link.field_interviewee_education_revision_id   = degree_target.revision_id
AND
    link.field_interviewee_education_value         = date_target.entity_id
AND
    link.field_interviewee_education_revision_id   = date_target.revision_id
AND
    link.field_interviewee_education_value         = school_link.entity_id
AND
    link.field_interviewee_education_revision_id   = school_link.revision_id
AND
    school_link.field_job_exp_institution_ref_nid  = school.nid
AND
    published.nid = field_data_field_interviewee_name.entity_id
-- AND
--     published.status = 1