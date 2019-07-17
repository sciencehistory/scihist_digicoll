module CHF
  # Our "Synthetic categories" are lists of works put together
  # based on other already existing metadata. For instance, any work
  # with a genre "Portraits" OR a subject "Portraits, Group" OR a
  # subject "Women in science" might be considered part of the
  # synthetic category "Portraits & People"
  #
  # At present, we do NOT index these categories, rather we just
  # dynamically fetch them by doing queries on a real index.
  #
  # There isn't right now API to determine what synthetic categories an
  # individual work belongs to (rather than just being in the results of a
  # fetch for the category), but there could be.
  class SyntheticCategory
    GENRE_FACET_SOLR_FIELD = ActiveFedora.index_field_mapper.solr_name("genre_string", :facetable)
    SUBJECT_FACET_SOLR_FIELD = ActiveFedora.index_field_mapper.solr_name("subject", :facetable)

    class_attribute :definitions, instance_writer: false
    # Different collections keyed by colleciton symbol, value is a hash
    # listing genres and subjects. Thing is member of synthetic collection
    # if it has _any_ of the listed genres or _any_ of the listed subjects.
    self.definitions = {
      health_and_medicine: {
        title: "Health & Medicine",
        description: "This digital collection features selected medications and documents, manuals, and photographs relating to biochemical research and technology, with a focus on 20th-century instrumentation in medical laboratories. Various models of glucose, enzyme, and amino acid analyzers are a few of the instruments documented in these materials.",
        subject: [
          "Toxicology",
          "Gases, Asphyxiating and poisonous--Toxicology",
          "Biology",
          "Biochemistry",
          "Hearing aids",
          "Drugs",
          "Electronics in space medicine",
          "Infants--Health and hygiene",
          "Medical botanists",
          "Medical education",
          "Medical electronics",
          "Medical electronics--Equipment and supplies",
          "Medical instruments and apparatus",
          "Medical laboratories--Equipment and supplies",
          "Medical laboratories--Equipment and supplies--Standards",
          "Medical laboratory equipment industry",
          "Medical physics",
          "Medical sciences",
          "Medical students",
          "Medical technologists",
          "Medicine",
          "Medicine bottles",
          "Newborn infants--Medical care",
          "Public health",
          "Space medicine",
          "Women in medicine"
        ]
      },
      scientific_education: {
        genre: ["Chemistry sets", "Molecular models"],
        subject: ["Science--Study and teaching"],
        description: "This digital collection features selected chemistry sets, molecular models, and science kits used for both instruction and play, all primarily from the mid-20th century. Some of these objects were previously on display in the Institute's museum as part of the Science at Play exhibition. Materials in this collection also include lecture notes, such as Louis Pasteur’s on stereochemistry, as well as letters between scientists concerning the state of scientific education."
      },
      alchemy: {
        subject: ["Alchemy", "Alchemists"],
        description: "This digital collection features selected manuscripts, rare books, paintings, and ephemera relating to alchemical topics and experimentation. Materials in this collection include depictions of alchemists’ workshops and pursuits on philosophy, magic, medicine, spiritual wisdom, and the transformation of matter."
      },
      periodic_tables: {
        subject: ["Chemical elements", "Mendeleyev, Dmitry Ivanovich, 1834-1907", "Periodic law", "Periodic table of the elements"],
        title: "Periodic Tables",
        description: "This digital collection features selected visual representations of the periodic table of the elements, with an emphasis on alternative layouts including circular, cylindrical, pyramidal, spiral, and triangular forms. Ranging in date from the 1860s to the 1990s, the materials provide a panorama of the historic evolution of the periodic table following Dmitri Mendeleev's initial 1869 design. Illustrations depicting chemical elements and concepts in atomic theory are also included in this collection."
      },
      science_on_stamps: {
        subject: ["Science on postage stamps"],
        description: "This digital collection features selected postage stamps and other philatelic materials depicting various aspects of science: from molecules and chemical reactions to portraits of Nobel Prize laureates. Materials in this collection, dating from 1887 to 2000, include stamps and first day covers, as well as commemorative and postmarked envelopes and postcards. Most of the items were selected from the Witco Stamp Collection in the Institute's archives."
      },
      instruments_and_innovation: {
        title: "Instruments & Innovation",
        genre: ["Scientific apparatus and instruments"],
        subject: ["Artillery", "Machinery", "Chemical apparatus",
                  "Laboratories--Equipment and supplies",
                  "Chemical laboratories--Equipment and supplies",
                  "Glassware"],
        description: "This digital collection features selected scientific instruments, apparatus, and analytical tools from the Institute's museum as well as photographs, rare-book engravings, and illustrations depicting various types of equipment and machinery found in laboratories, manufacturing plants, and mechanical treatises. Inventions from book wheels to fireballs can be found here, alongside more modern innovations such as Gammacells and Geiger counters."
      }
    }

    def self.has_key?(category_key)
      return unless category_key.present?
      definitions.has_key?(category_key.to_sym)
    end

    def self.keys
      definitions.keys
    end

    def self.all
      keys.collect { |key| self.new(key) }
    end

    # Our symbol keys use underscores eg `:portraits_and_people`, but it's nicer
    # to have hyphens in the URL eg `/portraits-and-people`. Look up a SyntheticCategory
    # object from slug in URL.
    def self.from_slug(slug)
      if slug.blank?
        nil
      elsif has_key?(slug)
        self.new(slug)
      elsif has_key?(slug.underscore)
        self.new(slug.underscore)
      else
        nil
      end
    end


    attr_accessor :category_key

    # Our symbol keys use underscores eg `:portraits_and_people`, but it's nicer
    # to have hyphens in the URL eg `/portraits-and-people`. Translate to a slug
    # suitable for use in a URL, see also .from_slug.
    def slug
      category_key.to_s.dasherize
    end

    def initialize(category_key)
      unless self.class.has_key?(category_key)
        raise ArgumentError, "No such category key: #{category_key}"
      end
      @category_key = category_key.to_sym
    end

    def title
      # This could use i18n, but this simpler seems good enough for now,
      # We don't even use locales anyway.
      if definition.has_key?(:title)
        definition[:title]
      else
        category_key.to_s.humanize.titlecase
      end
    end

    def description
      # This could use i18n, but this simpler seems good enough for now,
      # We don't even use locales anyway.
      if definition.has_key?(:description_html)
        definition[:description_html].html_safe
      elsif definition.has_key?(:description)
        definition[:description]
      else
        nil
      end
    end

    def solr_fq
      fq_elements = []

      if definition[:subject].present?
        fq_elements << "#{SUBJECT_FACET_SOLR_FIELD}:(#{fq_or_statement definition[:subject]})"
      end
      if definition[:genre].present?
        fq_elements << "#{GENRE_FACET_SOLR_FIELD}:(#{fq_or_statement definition[:genre]})"
      end

      fq_elements.join(" OR ")
    end

    def thumb_asset_path
      "synthetic_categories/#{category_key}_2x.jpg"
    end

    protected

    def definition
      definitions[category_key]
    end

    def fq_or_statement(values)
      values.
        collect { |s| s.gsub '"', '\"'}. # escape double quotes
        collect { |s| %Q{"#{s}"} }. # wrap in quotes
        join(" OR ")
    end


  end
end
