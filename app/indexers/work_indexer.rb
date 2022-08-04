# Solr indexing for our work class.
class WorkIndexer < Kithe::Indexer
  configure do
    # instead of a Solr field per attribute, we group them into fields
    # that will have similar boosting, to use solr more efficiently.
    # text1 is boosted highest, text2 next highest, etc.

    to_field "model_pk_ssi", obj_extract("id") # the actual db pk, a UUID

    to_field "text1_tesim", obj_extract("title")
    to_field "text1_tesim", obj_extract("additional_title")

    to_field ["text2_tesim","creator_facet", "more_like_this_tsimv"], obj_extract("creator", "value")
    to_field ["text2_tesim", "genre_facet",  "more_like_this_tsimv"], obj_extract("genre")

    to_field ["text3_tesim", "subject_facet", "more_like_this_tsimv"], obj_extract("subject")



    # Interviewer out of creator facet for use specifically for Oral History collection
    to_field "interviewer_facet" do |record, acc|
      acc.concat record.creator.find_all { |creator| creator.category == "interviewer"}.collect(&:value)
    end


    # index description to it's own field for highlighting purposes. Fields with
    # HTML in them need to have it stripped before indexing.
    to_field ["description_text4_tesim", "more_like_this_tsimv"] , obj_extract("description"), transform(->(val) { ActionView::Base.full_sanitizer.sanitize(val) })
    to_field "text4_tesim", obj_extract("provenance"), transform(->(val) { ActionView::Base.full_sanitizer.sanitize(val) })

    to_field ["text_no_boost_tesim", "language_facet"], obj_extract("language")
    to_field "text_no_boost_tesim", obj_extract("external_id", "value")
    to_field "text_no_boost_tesim", obj_extract("related_url")
    to_field ["text_no_boost_tesim", "place_facet",  "more_like_this_tsimv"], obj_extract("place", "value")
    to_field "text_no_boost_tesim", obj_extract("related_url")
    to_field ["text_no_boost_tesim", "department_facet", "more_like_this_tsimv"], obj_extract("department")
    to_field ["text_no_boost_tesim", "medium_facet",     "more_like_this_tsimv" ], obj_extract("medium")
    to_field ["text_no_boost_tesim", "format_facet",     "more_like_this_tsimv" ], obj_extract("format"), transform(->(v) { v.titleize })
    to_field ["text_no_boost_tesim", "rights_facet"], obj_extract("rights") # URL id
    to_field ["text_no_boost_tesim"], obj_extract("rights"), transform(->(v) { RightsTerm.label_for(v) }) # human label
    to_field "text_no_boost_tesim", obj_extract("rights_holder")
    to_field "text_no_boost_tesim", obj_extract("series_arrangement")

    to_field "text_no_boost_tesim", obj_extract("inscription"), transform(->(v) { "#{v.location}: #{v.text}" })
    to_field "text_no_boost_tesim", obj_extract("additional_credit"), transform(->(v) { "#{v.role}: #{v.name}" })
    
    to_field "text_no_boost_tesim", obj_extract("digitization_funder")
    to_field "text_no_boost_tesim", obj_extract("extent")

    to_field "text_no_boost_tesim", obj_extract("physical_container"), transform( ->(v) { v.display_as })

    # We put these in a separate field, cause we only allow logged in users
    # to search them
    to_field "admin_only_text_tesim", obj_extract("admin_note")
    to_field ["admin_only_text_tesim", "exhibition_facet"], obj_extract("exhibition")

    # for date/year range facet
    to_field "year_facet_isim" do |record, acc|
      acc.concat(DateIndexHelper.new(record).expanded_years)
    end

    # For sorting by oldest first
    to_field "earliest_date" do |record, acc|
      # for Solr, we need in "xml schema" format, with 00:00:00 time, and UTC timezone
      # Rails date extensions are confusing, but this works to get it.
      acc << DateIndexHelper.new(record).min_date&.in_time_zone("UTC")&.xmlschema
    end

    # for sorting by newest first
    to_field "latest_date" do |record, acc|
      # for Solr, we need in "xml schema" format, with 00:00:00 time, and UTC timezone
      # Rails date extensions are confusing, but this works to get it.
      acc << DateIndexHelper.new(record).max_date&.in_time_zone("UTC")&.xmlschema
    end


    # We need to know what collection(s) this work is in, to support search-within-a-collection.
    #
    # NOTE: This will do an SQL query to fetch collection ids, if are you indexing a bunch
    # at once, you should eager-load contains_contained_by assoc to join table.
    #
    # NOTE: If Collection contained by changes for a work, it needs to be reindexed.
    # Right now we only allow collection membership to be changed in the UI on the Work
    # edit page, and clicking save will re-index the work anyway (need to test to be sure).
    # But if you are programmatically changing the join table objects, beware.
    to_field "collection_id_ssim", obj_extract("contains_contained_by", "to_a", "container_id")


    # Note standard created_at, updated_at, and published are duplicated
    # in CollectionIndexer. Maybe we want to DRY it somehow.
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

    # For oral histories, we want a facet with what features/media types are included.
    # We use format including "Sound" as a proxy for whether there are audio recordings -- we
    # don't currently have architecture to efficiently access whether there are actually any
    # children of audio type, so we just count on 'format' being set appropriately.
    #
    # For OHMS transcript, we can actually check directly.
    to_field "oh_feature_facet" do |rec, acc|
      if rec.is_oral_history?
        acc << "Audio recording" if rec.format&.include?("sound")
        acc << "Transcript" if rec.format&.include?("text")

        if rec.oral_history_content && (rec.oral_history_content.has_ohms_transcript?  || rec.oral_history_content.has_ohms_index?)
          acc << "Synchronized audio"
        end
      end
    end

    to_field "oh_availability_facet" do |rec, acc|
      if rec.is_oral_history? && rec.oral_history_content
        acc << case rec.oral_history_content.available_by_request_mode
        when "automatic"
          "Upon request"
        when "manual_review"
          "Permission required"
        when "off"
          "Immediate"
        end
      end
    end

    # WARNING: changes to interviewee_biography data or links don't automatically trigger Work
    # reindex, although may require a reindex of associated works. We handle it just in
    # controller update actions.

    # We need the #to_a in there to get past the `ActiveRecord::Associations::CollectionProxy` cause it isn't
    # REALLY an array. https://github.com/sciencehistory/kithe/issues/119
    to_field "oh_institution_facet",
        obj_extract("oral_history_content", "interviewee_biographies", "to_a", "school", "institution"),
        obj_extract("oral_history_content", "interviewee_biographies",  "to_a", "job", "institution"),
        unique

    to_field "oh_birth_country_facet", obj_extract("oral_history_content", "interviewee_biographies", "to_a", "birth", "country_name")

    # Oral History Transcript and Table of Contents elements to a highlighted field
    #
    # 1. Transcript text, use OHMS transcript if we got it, otherwise plaintext if
    # we got it.
    #
    # 2. If OHMS Table of Contents is present: title, synopsis, and keywords
    to_field "searchable_fulltext_en" do |rec, acc|
      if rec.oral_history_content
        if rec.oral_history_content.has_ohms_transcript?
          text = rec.oral_history_content.ohms_xml.transcript_text

          # remove note references and footnotes markup
          text.gsub!(%r{\[\[footnote\]\]\d+\[\[\/footnote\]\]}, '')
          text.gsub!(%r{\[\[footnotes\]\]|\[\[\/footnotes\]\]|\[\[note\]\]|\[\[\/note\]\]}, '')

          acc << text
        elsif rec.oral_history_content.searchable_transcript_source.present?
          acc << rec.oral_history_content.searchable_transcript_source
        end

        if rec.oral_history_content.has_ohms_index?
          rec.oral_history_content.ohms_xml.index_points.each do |index_point|
            acc << index_point.keywords.join("; ") if index_point.keywords.present?
            acc << index_point.title if index_point.title.present?
            acc << index_point.synopsis if index_point.synopsis.present?
          end
        end
      end

      acc.concat get_string_from_each_published_member(rec, :english_translation)

      # Index the transcription here if we can assume that the work is entirely in English.
      acc.concat get_string_from_each_published_member(rec, :transcription) if rec.language == ['English']
    end

    to_field "searchable_fulltext_de" do |rec, acc|
      # Index the transcription here if we can assume that the work is entirely in German.
      acc.concat get_string_from_each_published_member(rec, :transcription) if rec.language == ['German']
    end


    # Index the transcription here unless we have place to index it in our language-specific indexes.
    to_field "searchable_fulltext_language_agnostic" do |rec, acc|
      entirely_in_english = (rec.language == ['English'])
      entirely_in_german =  (rec.language == ['German'])
      acc.concat get_string_from_each_published_member(rec, :transcription) unless entirely_in_english || entirely_in_german
    end

    # add a 'translation' token in bredig_feature_facet if we have any translations
    to_field ["bredig_feature_facet", "more_like_this_tsimv"] do |rec, acc|
      if rec.members && rec.members.any? {|m| m.is_a?(Asset) && m.english_translation.present? }
        acc << "English Translation"
      end
    end

    # for oral histories, get biographical data. Some to same field as subject (text3_tesim), some
    # to our general-purpose "text_no_boost_tesim"
    each_record do |rec, context|
      if rec.is_oral_history? && rec.oral_history_content
        biographies = rec.oral_history_content.interviewee_biographies

        boosted_text = []

        boosted_text.concat biographies.collect(&:school).flatten.collect(&:institution).compact
        boosted_text.concat biographies.collect(&:job).flatten.collect(&:institution).compact
        boosted_text.concat biographies.collect(&:honor).flatten.collect(&:honor).compact.collect { |val| ActionView::Base.full_sanitizer.sanitize(val) }
        boosted_text.uniq!

        context.add_output("text3_tesim", *boosted_text)



        standard_text = []
        standard_text.concat biographies.collect(&:birth).collect { |b| b.displayable_values.join(", ") if b }.compact
        standard_text.concat biographies.collect(&:death).collect { |d| d.displayable_values.join(", ") if d}.compact
        standard_text.concat biographies.collect(&:school).flatten.collect { |v| v.displayable_values.join(", ")}
        standard_text.concat biographies.collect(&:job).flatten.collect { |v| v.displayable_values.join(", ")}
        standard_text.concat biographies.collect(&:honor).flatten.collect { |v| v.displayable_values.join(", ")}
        standard_text.uniq!

        context.add_output("text_no_boost_tesim", *standard_text)
      end
    end
  end

  # Iterate over all members of a work, collecting a string from each one that is published.
  #
  # Return non-null strings in an array suitable for indexing.
  #
  # @param string_property a property to collect from each member of the work
  # @return [Array<String>] an array of strings containing the contents of @string_property for each member, in order.
  # @example Collect all non-null english translations from all members of my_work, in order:
  #   get_string_from_each_member(my_work, :english_translation) #=> ["english_translation_of_page_1", "english_translation_of_page_2", "english_translation_of_page_4"]
  def get_string_from_each_published_member(work, string_property)
    # careful, work.members can be nil.
    return [] unless work.members.present?
    work.members.sort_by { |m| m.position || 0 }.map {|mem| mem.asset? && mem.published?.presence && mem.send(string_property) }.compact
  end

end
