module FedoraCheck
  class FedoraUnneededMetadata

    #For each item of metadata we don't need, provides an explanation.
    def self.unneeded_for_all
      {
        '@type' =>
          """We use hasModel instead.""",

        # Dates:
        'http://fedora.info/definitions/v4/repository#created' =>
          """We use 'http://purl.org/dc/terms/dateSubmitted instead.' """,
        'http://fedora.info/definitions/v4/repository#lastModified' =>
          """We're using http://purl.org/dc/terms/modified.""",

        #Creators and modifiers:
        'http://fedora.info/definitions/v4/repository#createdBy' =>
          """We are not using this in qthe new app.""",
        'http://scholarsphere.psu.edu/ns#proxyDepositor' =>
          """We are not using this in the new app.""",
        'http://purl.org/dc/terms/creator' =>
          """We are not using this in the new app.""",
        'http://id.loc.gov/vocabulary/relators/dpt' =>
          """We are not using this in the new app.""",
        'http://fedora.info/definitions/v4/repository#lastModifiedBy' =>
          """We are not using this in the new app.""",
        'http://scholarsphere.psu.edu/ns#onBehalfOf' =>
          """We don't use this in Fedora""",

        #Relationships between items:
        'http://fedora.info/definitions/v4/repository#hasParent' =>
          """This is always '/fedora/rest/prod'.""",
        'http://purl.org/dc/terms/isPartOf' =>
          """This is always '/ad/mi/n_/se/admin_set/default'.""",
        'http://www.iana.org/assignments/relation/last' =>
          """This is redundant; we get the same information from 'http://www.w3.org/ns/ldp#contains' """,

        #Access control:
        'http://fedora.info/definitions/v4/repository#writable' =>
          """This is always true.""",
        'http://fedora.info/definitions/1/0/access/ObjState#objState' =>
          """This is always 'http://fedora.info/definitions/1/0/access/ObjState#active.' """,
        'http://projecthydra.org/ns/auth/acl#hasEmbargo' =>
          """We don't use embargos or leases.""",
        'http://projecthydra.org/ns/auth/acl#hasLease' =>
          """We don't use embargos or leases.""",

        #Other:
        'http://bibframe.org/vocab/creditsNote' =>
          """This is always the same default string for everything in the collection.""",
        'http://www.ebu.ch/metadata/ontologies/ebucore/ebucore#hasRelatedImage' =>
          """We are only migrating the representative, not the thumbnail.""",
        'http://scholarsphere.psu.edu/ns#relativePath' =>
          """Filenames come from the file-level information in Fedora""",
      }
    end

    def self.unneeded_for_generic_works
      {
        'http://pcdm.org/models#hasMember' =>
          """We only use this for collections. We get membership info for GenericWorks from
            'http://www.w3.org/ns/ldp#contains'. """,
        'info:fedora/fedora-system:def/model#downloadFilename' =>
          """The new system stores file name information
          strictly at the asset and file levels.""",
      }
    end

    def self.unneeded_for_file_sets
      {
        'info:fedora/fedora-system:def/model#downloadFilename' =>
          """Assets get their filenames from the file-level information in Fedora.""",
        'http://scholarsphere.psu.edu/ns#importUrl' =>
          """We are not using this in the new app""",
        'http://www.w3.org/ns/ldp#contains' =>
          """We get file metadata from http://pcdm.org/models#hasFile""",
        'http://purl.org/dc/elements/1.1/creator' =>
          """We don't use file set creator information."""
      }
    end

    def self.unneeded_for_collections
      {
        'http://chemheritage.org/ns/collection-thumb' =>
          """Collection thumbnails are handled differently.""",
        'http://www.w3.org/ns/ldp#contains' =>
          """We get collection membership metadata from http://pcdm.org/models#hasMember"""
      }
    end

    def self.unneeded_keys(target_class)
      keys = self.unneeded_for_all.keys
      if target_class == Work
        keys = keys + self.unneeded_for_generic_works.keys
      elsif target_class == Asset
        keys = keys + self.unneeded_for_file_sets.keys
      elsif target_class == Collection
        keys = keys + self.unneeded_for_collections.keys
      end
      keys
    end
  end
end