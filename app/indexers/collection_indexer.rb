# Solr indexing for our Collection class. There isn't much to index, but there's a bit.
class CollectionIndexer < Kithe::Indexer
  configure do
    # instead of a Solr field per attribute, we group them into fields
    # that will have similar boosting, to use solr solr more efficiently.
    # text1 is boosted highest, text2 next highest, etc.

    to_field "model_pk_ssi", obj_extract("id") # the actual db pk, a UUID

    to_field "text1_tesim", obj_extract("title")

    to_field "text4_tesim", obj_extract("description"), transform(->(val) { ActionView::Base.full_sanitizer.sanitize(val) })

    to_field "text_no_boost_tesim", obj_extract("related_link", "label")
    to_field "text_no_boost_tesim", obj_extract("related_link", "url")

    to_field "date_created_dtsi" do |rec, acc|
      if rec.created_at
        acc << rec.created_at.utc.iso8601
      end
    end

    to_field "date_modified_dtsi" do |rec, acc|
      if rec.updated_at
        acc << rec.updated_at.utc.iso8601
      end
    end

    to_field "date_published_dtsi" do |rec, acc|
      if rec.published_at
        acc << rec.published_at.utc.iso8601
      end
    end


    # for now we index 'published', not sure if we'll move to ONLY indexing
    # things that are published.
    to_field "published_bsi", obj_extract("published?")

  end
end
