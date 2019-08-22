
# Serializes one work to oai_dc XML (as string).
#
# Used for our oai_pmh implementation.
#
#    WorkOaiDcSerialization.new(work).to_oai_dc
#      # => XML string
#
#    WorkOaiDcSerialization.new(work).to_oai_dc(xml_decleration: true)
#
#
# ## Eager loading
#
# The serializer will use these associations, so they should be eager-loaded:
# * leaf_representative
class WorkOaiDcSerialization
  # all of em from https://drive.google.com/file/d/1fJEWhnYy5Ch7_ef_-V48-FAViA72OieG/view
  # why not, be complete in case we need em.
  NAMESPACES = {
    dpla: "http://dp.la/about/map/",
    cnt: "http://www.w3.org/2011/content#",
    dc: "http://purl.org/dc/elements/1.1/",
    dcterms: "http://purl.org/dc/terms/",
    dcmitype: "http://purl.org/dc/dcmitype/",
    edm: "http://www.europeana.eu/schemas/edm/",
    gn: "http://www.geonames.org/ontology#",
    oa: "http://www.w3.org/ns/oa#",
    ore: "http://www.openarchives.org/ore/terms/",
    rdf: "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
    rdfs: "http://www.w3.org/2000/01/rdf-schema#",
    skos: "http://www.w3.org/2004/02/skos/core#",
    svcs: "http://rdfs.org/sioc/services",
    wgs84: "http://www.w3.org/2003/01/geo/wgs84_pos#",
    oai_dc: "http://www.openarchives.org/OAI/2.0/oai_dc/"
  }

  # Which roles from our Creator model become dc:creator?
  CREATOR_ROLES = %w{
    creator_of_work
    artist
    author
    engraver
    manufacturer
    photographer
  }

  # Which roles from our Creator model become dc:contributor?
  # All of them that aren't CREATOR_ROLES except a few.
  # 'publisher' goes elsehwere, some others like manner_of and school_of aren't
  # really dc:contributors.
  CONTRIBUTOR_ROLES = Work::Creator::CATEGORY_VALUES - CREATOR_ROLES - %w{manner_of school_of publisher}

  attr_reader :work

  # @param solr_document [SolrDocument] represneting a GenericWork
  def initialize(work)
    @work = work
  end


  # a string, which does not have an XML decleration or DTD
  def to_oai_dc(xml_decleration: false)
    save_options = if xml_decleration
      Nokogiri::XML::Node::SaveOptions::FORMAT
    else
      Nokogiri::XML::Node::SaveOptions::FORMAT + Nokogiri::XML::Node::SaveOptions::NO_DECLARATION
    end
    as_oai_dc_builder.to_xml(save_with: save_options)
  end

  # A Nokogiri doc
  def as_oai_dc_builder
    builder = Nokogiri::XML::Builder.new do |xml|
      # have to use a hack for namespaced root element before we've provided the namespaces.
      xml.send("oai_dc:dc", xmlns_attribs) do
        xml["dc"].identifier in_our_app_url

        xml["dc"].title work.title

        if work.rights.present?
          xml["dc"].rights work.rights
        end

        dc_creators.each do |creator|
          xml["dc"].creator creator
        end

        dc_contributors.each do |contributor|
          xml["dc"].contributor contributor
        end

        # Very unclear what minimal requirements for parseable date formats are.
        # We're just going to put our human-readable dates in a single dc:date, cause
        # PA Digital guidelines say they are not repeatable. We may have to do more
        # work later to give them something they can parse, even if we dumb our dates
        # down.
        display_dates = DateDisplayFormatter.new(work.date_of_work).display_dates
        if display_dates.present?
          xml["dc"].date display_dates.join(", ")
        end

        if work.description.present?
          xml["dc"].description work.description
        end

        # Mime types in DC:format
        # work_presenter.content_types.each do |ctype|
        #   xml["dc"].format ctype
        # end

        # PA Digital says language IS repeatable, and there's no need to actually give them
        # ISO 692-2, they'd just throw it out anyway.
        (work.language || []).each do |lang|
          xml["dc"].language lang
        end

        (publishers || []).each do |publisher|
          xml["dc"].publisher publisher
        end

        if work.rights.present?
          xml["dcterms"].rightsholder work.rights
        end

        # Could do: dc:source archival location. A pain cause it requires collection, and
        # PA Digital says they don't currently pass it on to DPLA anyway, so we'll skip for now.
        # See CitableAttributes#archive_location for how we do it there.

        (work.subject || []).each do |subject|
          xml["dc"].subject subject
        end

        # PA Digital says dc:type IS repeatable.
        (work.format || []).each do |type|
          xml["dc"].type type
        end

        # PA digital also says dc:type is the place to put any local vocab, so
        # we'll try our genres in there too.
        Array(work.genre).each do |genre|
          xml["dc"].type genre.downcase
        end



        if medium_download_size_url.present?
          # PA Digital wants the thumbnail in a repeated dc:identifier, okay then!
          xml["dc"].send(:"identifier", medium_download_size_url)
        end

        ########################
        #
        # PA Digital will probably throw these out and not forward them to DPLA, but they
        # are tags DPLA MAP asks for, we might as well include them so they are there in the future
        # if anyone wants em, without us having to code em then.

        xml["dpla"].originalRecord in_our_app_url
        if medium_download_size_url.present?
          xml["edm"].preview medium_download_size_url
        end

        if work.rights.present?
          xml["edm"].rights work.rights
        end

        Array(work.genre).each do |genre|
          xml["edm"].hasType genre.downcase
        end

        # "The URL of a suitable source object in the best resolution available on the website of the Data
        # "Provider from which edm:preview could be generated for use in available portal."
        #
        # BEST resolution available? OK, we'll give them the full jpg.
        if full_jpg_url.present?
          xml["edm"].object full_jpg_url
        end
      end
    end
  end

  protected

  def routes
    @routes ||= Class.new do
      # somewhere said this is a better way to use global routes to avoid memory leak in rails
      include Rails.application.routes.url_helpers
    end.new
  end

  def in_our_app_url
    # A bit cheaper to do this without Rails route helper, and doesn't require us to
    # figure out how to get access to Rails route helper. Does mean it'll break
    # if our routes change, but this is one unlikely to.
    @in_our_app_url ||= "#{ScihistDigicoll::Env.lookup!(:app_url_base)}/works/#{work.friendlier_id}"
  end

  def dc_creators
    # We'll use the same subset of all our 'maker' fields we use in our citations in CitableAttributes
    @dc_creators ||= work.creator.find_all { |creator| CREATOR_ROLES.include?(creator.category) }.collect(&:value)
  end

  def dc_contributors
    @dc_contributors ||= work.creator.find_all { |creator| CONTRIBUTOR_ROLES.include?(creator.category) }.collect(&:value)
  end

  def publishers
    @publishers ||= work.creator.find_all { |creator| creator.category.to_s == "publisher" }.collect(&:value)
  end


  # We are using our app url that will REDIRECT to S3:
  # 1) in case the S3 URL changes, this one, sent to oai-pmh clients, should remain good
  #    (as long as representative asset ID remains good for a work -- we could create a new
  #    URL that takes work URL and redirects?)
  # 2) To avoid the performance hit of loading the derivative and figuring out it's S3 URL
  #    at oai-pmh time.
  #
  # We are hand-building the URL instead of using Rails route helper to further improve
  # perfomrance and avoid the need to have rails route helpers here. Our tests
  # should still test with rails route helpers.
  def medium_download_size_url
    @medium_download_size_url ||= "#{ScihistDigicoll::Env.lookup!(:app_url_base)}/downloads/#{work.leaf_representative.friendlier_id}/download_medium?disposition=inline"
  end

  def full_jpg_url
    @full_jpg_url ||= "#{ScihistDigicoll::Env.lookup!(:app_url_base)}/downloads/#{work.leaf_representative.friendlier_id}/download_full?disposition=inline"
  end

  def xmlns_attribs
    NAMESPACES.collect do |key, value|
      ["xmlns:#{key.to_s}", value]
    end.to_h
  end

end

