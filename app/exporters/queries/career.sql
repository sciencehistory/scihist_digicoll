select
    JSON_ARRAYAGG(
        JSON_OBJECT(
            'interviewee_name',
            field_interviewee_name_value,
            'interview_entity_id',
            field_data_field_interviewee_name.entity_id,
            'interview_number',
            field_data_field_interview_number.field_interview_number_value,
            'job_id',
            link.field_interviewee_experience_value,
            'job_title',
            job_title.field_job_title_value,
            'job_start_date',
            date_target.field_date_span_value,
            'job_end_date',
            date_target.field_date_span_value2,
            'employer_id',
            employer_link.field_job_exp_institution_ref_nid,
            'employer_name',
            employer.title
        )
    )
from
    field_data_field_interviewee_name,
    field_data_field_interview_number,
    field_data_field_interviewee_experience             link,
    field_data_field_job_title                          job_title,
    field_data_field_date_span                          date_target,
    field_data_field_job_exp_institution_ref            employer_link,
    node                                                employer
WHERE
    field_data_field_interviewee_name.entity_id    = field_data_field_interview_number.entity_id
AND
    field_data_field_interviewee_name.revision_id  = field_data_field_interview_number.revision_id
AND
    field_data_field_interviewee_name.entity_id    = link.entity_id
AND
    field_data_field_interviewee_name.revision_id  = link.revision_id
AND
    link.field_interviewee_experience_value        = job_title.entity_id
AND
    link.field_interviewee_experience_revision_id  = job_title.revision_id
AND
    link.field_interviewee_experience_value        = date_target.entity_id
AND
    link.field_interviewee_experience_revision_id  = date_target.revision_id
AND
    link.field_interviewee_experience_value         = employer_link.entity_id
AND
    link.field_interviewee_experience_revision_id   = employer_link.revision_id
AND
    employer_link.field_job_exp_institution_ref_nid  = employer.nid