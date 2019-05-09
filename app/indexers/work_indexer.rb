# Solr indexing for our work class. Still a work in progress.
class WorkIndexer < Kithe::Indexer
  configure do
    # instead of a Solr field per attribute, we group them into fields
    # that will have similar boosting, to use solr solr more efficiently.
    # text1 is boosted highest, text2 next highest, etc.
    #.
    #
    # Experiment, not necessarily completed indexing logic.

    to_field "friendlier_id_ssi", obj_extract("friendlier_id")

    to_field "text1_tesim", obj_extract("title")
    to_field "text1_tesim", obj_extract("additional_title")

    to_field ["text2_tesim","creator_facet"], obj_extract("creator", "value")
    to_field ["text2_tesim", "genre_facet"], obj_extract("genre")

    to_field ["text3_tesim", "subject_facet"], obj_extract("subject")

    to_field "text4_tesim", obj_extract("description")
    to_field "text4_tesim", obj_extract("provenance")

    to_field ["text_no_boost_tesim", "language_facet"], obj_extract("language")
    to_field "text_no_boost_tesim", obj_extract("external_id", "value")
    to_field "text_no_boost_tesim", obj_extract("related_url")
    to_field ["text_no_boost_tesim", "place_facet"], obj_extract("place", "value")
    to_field "text_no_boost_tesim", obj_extract("related_url")
    to_field ["text_no_boost_tesim", "department_facet"], obj_extract("department")
    to_field ["text_no_boost_tesim", "medium_facet"], obj_extract("medium")
    to_field ["text_no_boost_tesim", "format_facet"], obj_extract("format")
    to_field ["text_no_boost_tesim", "rights_facet"], obj_extract("rights") # URL id
    to_field ["text_no_boost_tesim"], obj_extract("rights"), transform(->(v) { RightsTerms.label_for(v) }) # human label
    to_field "text_no_boost_tesim", obj_extract("rights_holder")
    to_field "text_no_boost_tesim", obj_extract("series_arrangement")

    to_field "text_no_boost_tesim", obj_extract("inscription"), transform(->(v) { "#{v.location}: #{v.text}" })
    to_field "text_no_boost_tesim", obj_extract("additional_credit"), transform(->(v) { "#{v.role}: #{v.name}" })
    to_field ["text_no_boost_tesim", "exhibition_facet"], obj_extract("exhibition")
    to_field ["text_no_boost_tesim", "project_facet"], obj_extract("project")
    to_field "text_no_boost_tesim", obj_extract("source")
    to_field "text_no_boost_tesim", obj_extract("extent")

    to_field "text_no_boost_tesim", obj_extract("physical_container"), transform( ->(v) { v.as_human_string })

    # We put this one in a separate field, cause we only allow logged in users
    # to search it
    to_field "admin_only_text_tesim", obj_extract("admin_note")

    # for date/year range facet
    to_field "year_facet_isim" do |record, acc|
      acc.concat(DateIndexHelper.new(record).expanded_years)
    end

    # For sorting by oldest first
    to_field "earliest_year" do |record, acc|
      acc << DateIndexHelper.new(record).min_year
    end

    # for sorting by newest first
    to_field "latest_year" do |record, acc|
      acc << DateIndexHelper.new(record).max_year
    end

    # Note standard created_at, updated_at, and published are duplicated
    # in CollectionIndexer. Maybe we want to DRY it somehow.


    # May want to switch to or add a 'date published' instead, right
    # now we only have date added to DB, which is what we had in sufia.
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

    # for now we index 'published', not sure if we'll move to ONLY indexing
    # things that are published.
    to_field "published_bsi", obj_extract("published?")
  end
end
