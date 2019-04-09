# Solr indexing for our work class. Still a work in progress.
class WorkIndexer < Kithe::Indexer
  configure do
    # instead of a Solr field per attribute, we group them into fields
    # that will have similar boosting, to use solr solr more efficiently.
    # text1 is boosted highest, text2 next highest, etc.
    #.
    #
    # Experiment, not necessarily completed indexing logic.

    to_field "text1_tesim", obj_extract("title")
    to_field "text1_tesim", obj_extract("additional_title")

    to_field ["text2_tesim","creator_facet"], obj_extract("creator", "value")
    to_field ["text2_tesim" "genre_facet"], obj_extract("genre")

    to_field ["text3_tesim", "subject_facet"], obj_extract("subject")

    to_field "text4_tesim", obj_extract("description")

    to_field "text_no_boost_tesim", obj_extract("language")
    to_field "text_no_boost_tesim", obj_extract("external_id", "value")
    to_field "text_no_boost_tesim", obj_extract("related_url")
    to_field "text_no_boost_tesim", obj_extract("place", "value")
    to_field "text_no_boost_tesim", obj_extract("related_url")
    to_field "text_no_boost_tesim", obj_extract("admin_note")
    to_field "text_no_boost_tesim", obj_extract("department")
    to_field "text_no_boost_tesim", obj_extract("medium")
    to_field ["text_no_boost_tesim", "format_facet"], obj_extract("format")
    to_field "text_no_boost_tesim", obj_extract("rights") # URL id
    to_field "text_no_boost_tesim", obj_extract("rights"), transform(->(v) { RightsTerms.label_for(v) }) # human label
    to_field "text_no_boost_tesim", obj_extract("rights_holder")
    to_field "text_no_boost_tesim", obj_extract("series_arrangement")

    to_field "text_no_boost_tesim", obj_extract("inscription"), transform(->(v) { "#{v.location}: #{v.text}" })
    to_field "text_no_boost_tesim", obj_extract("additional_credit"), transform(->(v) { "#{v.role}: #{v.name}" })
    to_field "text_no_boost_tesim", obj_extract("exhibition")
    to_field "text_no_boost_tesim", obj_extract("source")

    # TODO structured things we need to figure out how we want in text index:
    # physical container? Date?


    ## FACETS and SORTABLE FIELDS
    # TODO, including date facets.
  end
end
