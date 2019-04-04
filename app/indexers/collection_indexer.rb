# Solr indexing for our Collection class. There isn't much to index, but there's a bit.
class CollectionIndexer < Kithe::Indexer
  configure do
    # instead of a Solr field per attribute, we group them into fields
    # that will have similar boosting, to use solr solr more efficiently.
    # text1 is boosted highest, text2 next highest, etc.

    to_field "text1_tesim", obj_extract("title")

    to_field "text4_tesim", obj_extract("description")

    to_field "text_no_boost_tesim", obj_extract("related_url")
  end
end
