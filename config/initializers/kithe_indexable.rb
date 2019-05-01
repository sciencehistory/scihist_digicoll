Kithe::Indexable.settings.solr_url = ScihistDigicoll::Env.lookup!(:solr_url)
# index to solr with solr `id` field being our friendlier_id
Kithe::Indexable.settings.solr_id_value_attribute = :friendlier_id
