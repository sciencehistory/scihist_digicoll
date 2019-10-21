module FedoraCheck
  # Useful mappings for checking fedora against
  class FedoraMappings
    def self.scalar_attributes
      { 'division' => 'department' }
    end
    def self.array_attributes
      {'genre_string' => 'genre' }
    end
    def self.additional_credit_roles
      {'photographer' => 'photographed_by'}
    end
    def self.dates
      {
          start:            "http://www.europeana.eu/schemas/edm/begin",
          start_qualifier:  "http://www.cidoc-crm.org/cidoc-crm/P79_beginning_is_qualified_by",
          finish:           "http://www.europeana.eu/schemas/edm/end",
          finish_qualifier: "http://www.cidoc-crm.org/cidoc-crm/P80_end_is_qualified_by",
          note:             "http://www.w3.org/2004/02/skos/core#note",
      }
    end
    def self.inscriptions
      {
        location:         "http://purl.org/vra/location",
        text:             "http://purl.org/vra/text",
      }
    end
    def self.physical_container
      {'b'=>'box', 'f'=>'folder', 'v'=>'volume',
        'p'=>'part', 'g'=>'page', 's'=>'shelfmark' }
    end

    # This is the output of the following code in Sufia:
    # Hash[ GenericWork.reflections.values.map do  |r|
    #  [ r.name,
    #     { uri: r.options[:predicate].to_s,
    #       class_name: r.options[:class_name],
    #       member_relation:r.options[:member_relation] }]
    #    end
    # ]
    def self.work_reflections
      {:members=>
        {:uri=>"",
         :class_name=>"ActiveFedora::Base",
         :member_relation=>nil},
       :list_source=>
        {:uri=>"",
         :class_name=>"ActiveFedora::Aggregation::ListSource",
         :member_relation=>nil},
       :ordered_member_proxies=>
        {:uri=>"", :class_name=>nil, :member_relation=>nil},
       :related_objects=>
        {:uri=>"",
         :class_name=>"ActiveFedora::Base",
         :member_relation=>nil},
       :files=>
        {:uri=>"",
         :class_name=>"Hydra::PCDM::File",
         :member_relation=>nil},
       :member_of_collections=>
        {:uri=>"",
         :class_name=>"ActiveFedora::Base",
         :member_relation=>nil},
       :access_control=>
        {:uri=>"http://www.w3.org/ns/auth/acl#accessControl",
         :class_name=>"Hydra::AccessControl",
         :member_relation=>nil},
       :access_control_id=>
        {:uri=>"http://www.w3.org/ns/auth/acl#accessControl",
         :class_name=>"Hydra::AccessControl",
         :member_relation=>nil},
       :representative=>
        {:uri=>
          "http://www.ebu.ch/metadata/ontologies/ebucore/ebucore#hasRelatedMediaFragment",
         :class_name=>"ActiveFedora::Base",
         :member_relation=>nil},
       :representative_id=>
        {:uri=>
          "http://www.ebu.ch/metadata/ontologies/ebucore/ebucore#hasRelatedMediaFragment",
         :class_name=>"ActiveFedora::Base",
         :member_relation=>nil},
       :thumbnail=>
        {:uri=>
          "http://www.ebu.ch/metadata/ontologies/ebucore/ebucore#hasRelatedImage",
         :class_name=>"ActiveFedora::Base",
         :member_relation=>nil},
       :thumbnail_id=>
        {:uri=>
          "http://www.ebu.ch/metadata/ontologies/ebucore/ebucore#hasRelatedImage",
         :class_name=>"ActiveFedora::Base",
         :member_relation=>nil},
       :admin_set=>
        {:uri=>"http://purl.org/dc/terms/isPartOf",
         :class_name=>nil,
         :member_relation=>nil},
       :admin_set_id=>
        {:uri=>"http://purl.org/dc/terms/isPartOf",
         :class_name=>nil,
         :member_relation=>nil},
       :embargo=>
        {:uri=>"http://projecthydra.org/ns/auth/acl#hasEmbargo",
         :class_name=>"Hydra::AccessControls::Embargo",
         :member_relation=>nil},
       :embargo_id=>
        {:uri=>"http://projecthydra.org/ns/auth/acl#hasEmbargo",
         :class_name=>"Hydra::AccessControls::Embargo",
         :member_relation=>nil},
       :lease=>
        {:uri=>"http://projecthydra.org/ns/auth/acl#hasLease",
         :class_name=>"Hydra::AccessControls::Lease",
         :member_relation=>nil},
       :lease_id=>
        {:uri=>"http://projecthydra.org/ns/auth/acl#hasLease",
         :class_name=>"Hydra::AccessControls::Lease",
         :member_relation=>nil},
       :date_of_work=>
        {:uri=>"http://purl.org/dc/elements/1.1/date",
         :class_name=>"DateOfWork",
         :member_relation=>nil},
       :date_of_work_ids=>
        {:uri=>"http://purl.org/dc/elements/1.1/date",
         :class_name=>"DateOfWork",
         :member_relation=>nil},
       :inscription=>
        {:uri=>"http://purl.org/vra/hasInscription",
         :class_name=>"Inscription",
         :member_relation=>nil},
       :inscription_ids=>
        {:uri=>"http://purl.org/vra/hasInscription",
         :class_name=>"Inscription",
         :member_relation=>nil},
       :additional_credit=>
        {:uri=>"http://chemheritage.org/ns/hasCredit",
         :class_name=>"Credit",
         :member_relation=>nil},
       :additional_credit_ids=>
        {:uri=>"http://chemheritage.org/ns/hasCredit",
         :class_name=>"Credit",
         :member_relation=>nil}}
    end

    # This is the output of the following code in Sufia:
    # Hash [ GenericWork.properties.map do |k, v| [k, v.predicate.to_s] end ]
    def self.properties
    {
      "has_model"=>"info:fedora/fedora-system:def/model#hasModel",
       "create_date"=>
        "http://fedora.info/definitions/v4/repository#created",
       "modified_date"=>
        "http://fedora.info/definitions/v4/repository#lastModified",
       "head"=>"http://www.iana.org/assignments/relation/first",
       "tail"=>"http://www.iana.org/assignments/relation/last",
       "depositor"=>"http://id.loc.gov/vocabulary/relators/dpt",
       "title"=>"http://purl.org/dc/terms/title",
       "date_uploaded"=>"http://purl.org/dc/terms/dateSubmitted",
       "date_modified"=>"http://purl.org/dc/terms/modified",
       "state"=>
        "http://fedora.info/definitions/1/0/access/ObjState#objState",
       "owner"=>"http://opaquenamespace.org/ns/hydra/owner",
       "proxy_depositor"=>
        "http://scholarsphere.psu.edu/ns#proxyDepositor",
       "on_behalf_of"=>
        "http://scholarsphere.psu.edu/ns#onBehalfOf",
       "arkivo_checksum"=>
        "http://scholarsphere.psu.edu/ns#arkivoChecksum",
       "label"=>
        "info:fedora/fedora-system:def/model#downloadFilename",
       "relative_path"=>
        "http://scholarsphere.psu.edu/ns#relativePath",
       "import_url"=>"http://scholarsphere.psu.edu/ns#importUrl",
       "part_of"=>"http://purl.org/dc/terms/isPartOf",
       "description"=>
        "http://purl.org/dc/elements/1.1/description",
       "date_created"=>"http://purl.org/dc/terms/created",
       "subject"=>"http://purl.org/dc/elements/1.1/subject",
       "language"=>"http://purl.org/dc/elements/1.1/language",
       "identifier"=>"http://purl.org/dc/terms/identifier",
       "based_near"=>"http://xmlns.com/foaf/0.1/based_near",
       "related_url"=>
        "http://www.w3.org/2000/01/rdf-schema#seeAlso",
       "bibliographic_citation"=>
        "http://purl.org/dc/terms/bibliographicCitation",
       "source"=>"http://purl.org/dc/elements/1.1/source",
       "creator"=>"http://purl.org/dc/terms/creator",
       "after"=>"http://chemheritage.org/ns/after",
       "artist"=>"http://id.loc.gov/vocabulary/relators/art",
       "attributed_to"=>
        "http://id.loc.gov/vocabulary/relators/att",
       "author"=>"http://id.loc.gov/vocabulary/relators/aut",
       "addressee"=>"http://id.loc.gov/vocabulary/relators/rcp",
       "creator_of_work"=>
        "http://purl.org/dc/elements/1.1/creator",
       "contributor"=>
        "http://purl.org/dc/elements/1.1/contributor",
       "editor"=>"http://id.loc.gov/vocabulary/relators/edt",
       "engraver"=>"http://id.loc.gov/vocabulary/relators/egr",
       "interviewee"=>"http://id.loc.gov/vocabulary/relators/ive",
       "interviewer"=>"http://id.loc.gov/vocabulary/relators/ivr",
       "manner_of"=>"http://chemheritage.org/ns/mannerOf",
       "school_of"=>"http://chemheritage.org/ns/schoolOf",
       "manufacturer"=>"http://id.loc.gov/vocabulary/relators/mfr",
       "photographer"=>"http://id.loc.gov/vocabulary/relators/pht",
       "printer"=>"http://id.loc.gov/vocabulary/relators/prt",
       "provenance"=>"http://chemheritage.org/ns/provenance",
       "printer_of_plates"=>
        "http://id.loc.gov/vocabulary/relators/pop",
       "publisher"=>"http://purl.org/dc/elements/1.1/publisher",
       "place_of_interview"=>
        "http://id.loc.gov/vocabulary/relators/evp",
       "place_of_manufacture"=>
        "http://id.loc.gov/vocabulary/relators/mfp",
       "place_of_publication"=>
        "http://id.loc.gov/vocabulary/relators/pup",
       "place_of_creation"=>
        "http://id.loc.gov/vocabulary/relators/prp",
       "additional_title"=>"http://purl.org/dc/terms/alternative",
       "admin_note"=>"http://chemheritage.org/ns/hasAdminNote",
       "credit_line"=>"http://bibframe.org/vocab/creditsNote",
       "division"=>"http://chemheritage.org/ns/hasDivision",
       "exhibition"=>"http://opaquenamespace.org/ns/exhibit",
       "project"=>"http://opaquenamespace.org/ns/project",
       "file_creator"=>
        "http://www.ebu.ch/metadata/ontologies/ebucore/ebucore#hasCreator",
       "genre_string"=>"http://chemheritage.org/ns/hasGenre",
       "extent"=>"http://chemheritage.org/ns/hasExtent",
       "medium"=>"http://chemheritage.org/ns/hasMedium",
       "physical_container"=>
        "http://bibframe.org/vocab/materialOrganization",
       "resource_type"=>"http://purl.org/dc/elements/1.1/type",
       "rights"=>"http://purl.org/dc/elements/1.1/rights",
       "rights_holder"=>
        "http://chemheritage.org/ns/hasRightsHolder",
       "series_arrangement"=>
        "http://bibframe.org/vocab/materialHierarchicalLevel",
       "digitization_funder"=>
        "http://chemheritage.org/ns/DigitizationFundedBy"
      }
    end
  end
end