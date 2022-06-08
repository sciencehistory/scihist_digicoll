Resque.redis = ScihistDigicoll::Env.persistent_redis_connection!

# Silence copious deprecation warnings until resque fixes them
# https://github.com/sciencehistory/scihist_digicoll/issues/1745
Redis.silence_deprecations = true
