Kithe.indexable_settings.solr_url = ScihistDigicoll::Env.lookup!(:solr_url)

# index to solr with solr `id` field being our friendlier_id
Kithe.indexable_settings.solr_id_value_attribute = :friendlier_id

# our fulltext transcripts are so large in bytes, a smaller batch size treats
# Solr better and helps reduce chance of Solr timeout.
Kithe.indexable_settings.batching_mode_batch_size = 30


# Insist on using `mediainfo` CLI for fallback content-type detection,
# will raise if not present.
Kithe.use_mediainfo = true
