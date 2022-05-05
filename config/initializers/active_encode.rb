# Set up ActiveEncode to use the MediaConvert adapter
#
# https://sciencehistory.atlassian.net/l/c/Hz0zMh4z

ActiveEncode::Base.engine_adapter = :media_convert

# Role that actual MediaConvert will use, needs access to
# relevant S3 buckets, and MediaConvert itself.
ActiveEncode::Base.engine_adapter.role = ScihistDigicoll::Env.lookup!("aws_mediaconvert_role_arn")

# Don't require a CloudWatch layer to get output results, just infer it from
# the MediaConvert job itself
ActiveEncode::Base.engine_adapter.direct_output_lookup = true

# We don't set the output_bucket config, we just use `destination` with complete
# S3 destination URLs with the ActiveEncode adapter
