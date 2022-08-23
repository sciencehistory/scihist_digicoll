# Our "Featured Topics" are lists of works put together
# based on other already existing metadata. For instance, any work
# with a genre "Portraits" OR a subject "Portraits, Group" OR a
# subject "Women in science" might be considered part of the
# featured topics "Portraits & People"
#
# At present, we do NOT index these categories. Rather, we just
# dynamically fetch them by doing queries on a real index.
#
# The genres and subjects associated with featured topics are in this file.
#
# Images should be 700x700 pixel squares, and are stored in a standard
# predicatable location at: ./app/assets/images/featured_topics/[TOPIC_KEY]_2x.jpg
#
#   * https://sciencehistory.atlassian.net/wiki/spaces/HDC/pages/1646428165/Creating+a+thumbnail+for+a+Featured+Topic
#
#   * (_2X indicates this is actually a double-resolution file, twice as big
#   as space on page, for high-res screens. We don't bother doing low-res alternate)
#
class FeaturedTopic
  SUBJECT_FACET_SOLR_FIELD = 'subject_facet'
  GENRE_FACET_SOLR_FIELD = 'genre_facet'

  class_attribute :definitions, instance_writer: false

  # Different featured topics, keyed by symbol. Value is a hash
  # listing titles, description, and genres and subjects.
  # A work is considered part of a of FeaturedTopic
  # if it has _any_ of the listed genres or _any_ of the listed subjects.
  #
  # FIRST FOUR, in order, will be featured on home page.
  self.definitions = {
    women_and_science: {
      title: "Women and Science",
      genre: [],
      subject: [
        "African American women",
        "Birth control",
        "Breast implants",
        "Breast pumps",
        "Breastfeeding",
        "Women--Health and hygiene",
        "Women biochemists",
        "Women botanists",
        "Women chemists",
        "Women employees",
        "Women in chemistry",
        "Women in information science",
        "Women in medicine",
        "Women in physics",
        "Women in the social sciences",
        "Women Nobel Prize winners",
        "Women physical scientists",
        "Women physicians",
        "Women physicists",
        "Women scientists",
        "Women in science",
        "Women in science--Study and teaching",
        "Women's health services"],
      description: "This digital collection features materials related to notable women scientists, including Marie Curie, Irène Joliot-Curie, Bettye Washington Greene, Dorothy Crowfoot Hodgkin, Stephanie Kwolek, and Rosalyn Yalow, as well as images of women working in a variety of laboratory and industrial settings. The collection also includes a range of materials related to women's health, including breast pumps, contraceptives, and mammary sizers."
    },
    food_science: {
      title: "Food Science",
      genre: [],
      subject: [
        "Baked products",
        "Baked products industry",
        "Baking",
        "Baking powder",
        "Biscuits",
        "Butter",
        "Bread",
        "Canning and preserving",
        "Carbohydrates",
        "Carbohydrates--Analysis",
        "Cake",
        "Chocolate",
        "Chocolate industry",
        "Cookbooks",
        "Cooking, American",
        "Coloring matter in food",
        "Desserts",
        "Dietetic foods",
        "Dinners and dining",
        "Flavoring essences",
        "Flavoring essences industry",
        "Flour industry",
        "Food--Analysis",
        "Food--Composition",
        "Food--Packaging",
        "Food--Preservation",
        "Food--Safety measures",
        "Food-Testing",
        "Food additives",
        "Food additives industry",
        "Food adulteration and inspection",
        "Food adulteration and inspection--Study and teaching",
        "Food contamination",
        "Food industry and trade",
        "Food industry and trade--Safety measures",
        "Food industry and trade--Sanitation",
        "Grocery trade",
        "Hershey Company",
        "Kellogg Company",
        "Kraft Foods Company",
        "Low-calorie diet",
        "Margarine",
        "Margarine--Marketing",
        "Meat extract",
        "Monosodium glutamate",
        "Nonnutritive sweeteners",
        "Nutrition",
        "Oils and fats",
        "Oils and fats--Analysis",
        "Oils and fats--Research",
        "Recipes",
        "Refrigerated foods",
        "Sugar",
        "Sugar trade",
        "Wheat--Research"
      ],
      description: "This digital collection features a broad spectrum of materials related to the production, packaging, and marketing of food, including advertisements, printed ephemera, recipe books, and photographs. Subjects represented in the collection include food additives and adulteration, flavoring essences, and safety standards, as well as food-adjacent topics such as sugar, monosodium glutamate (MSG), and margarine."
    },

    water: {
      title: "Water",
      subject: [
        "Bottled water",
        "Distilled water",
        "Drinking water",
        "Drinking water--Analysis",
        "Drinking water--Arsenic content",
        "Drinking water--Contamination",
        "Drinking water--Government policy",
        "Drinking water--Health aspects",
        "Drinking water--Law and legislation",
        "Drinking water--Lead content",
        "Drinking water--Microbiology",
        "Drinking water--Purification",
        "Drinking water--Safety measures",
        "Drinking water--Standards",
        "Drinking water--Testing",
        "Groundwater",
        "Mineral waters",
        "Mineral water industry",
        "Oceanography",
        "Oceanography--Research",
        "Safe Water Drinking Act of 1974 (United States)",
        "Saline water conversion plants",
        "Seawater",
        "Seawater--Analysis",
        "Seawater--Composition",
        "Seawater corrosion",
        "Seawater--Distillation",
        "Selters water",
        "Water",
        "Water--Analysis",
        "Water filters",
        "Water--Fluoridation",
        "Water--Fluoridation--Health aspects",
        "Water--Fluoridation--Standards",
        "Water-supply",
        "Water pollution",
        "Water-power",
        "Watershed management",
        "Watershed restoration",
        "Watersheds",
        "Watersheds--Analysis",
        "Watersheds--Environmental aspects",
        "Watersheds--Research",
        "Watersheds--Recreational use",
        "Water-wheels",
        "Water purification chemicals industry",
        "Water quality",
        "Water quality--Measurement",
        "Water quality management",
        "Water--Hardness",
        "Water--Hardness--Health aspects",
        "Water--Hardness--Physiological effect",
        "Water--Purification",
        "Water--Purification--Distillation process",
        "Water--Softening",
        "Water--Softening--Equipment and supplies",
        "Water--Testing",
        "Water resources development",
        "Water treatment plants",
        "Waterways",
        "Wells"
      ],
      description: "This digital collection features a broad spectrum of materials related to water quality, testing, and analysis, including advertisements, museum objects, oral history interviews, photographs, and print materials. Other subjects represented in the collection include distillation and filtration, water-power, water-hardness and softening, and the extraction of magnesium from seawater."
    },

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
    :oral_histories => {
      title: "Oral Histories",
      path: "/collections/#{ScihistDigicoll::Env.lookup!(:oral_history_collection_id)}"
    },
    instruments_and_innovation: {
      title: "Instruments & Innovation",
      genre: ["Scientific apparatus and instruments"],
      subject: ["Artillery", "Machinery", "Chemical apparatus",
                "Laboratories--Equipment and supplies",
                "Chemical laboratories--Equipment and supplies",
                "Glassware"],
      description: "This digital collection features selected scientific instruments, apparatus, and analytical tools from the Institute's museum as well as photographs, rare-book engravings, and illustrations depicting various types of equipment and machinery found in laboratories, manufacturing plants, and mechanical treatises. Inventions from book wheels to fireballs can be found here, alongside more modern innovations such as Gammacells and Geiger counters."
    },
    rare_earths: {
      title: "Rare Earths"
      description: "In this collection, find materials related to rare earth elements, a group of 17 elements composed of scandium, yttrium, and the lanthanides. These abundant elements, characterized by similar geochemical and magnetic properties, are mined for a variety of uses including magnets, alloys, glasses, and electronics. The diverse collection of materials found below demonstrates the range of uses for rare earths throughout the twentieth and twenty-first centuries. Browse the topic to find materials related to fine art, lasers, cathode ray tube televisions, the first incandescent lights, and more!"
      subject: ["Cathode ray tubes", "Cerium", "Dysprosium", "Erbium", "Europium", "Gadolinium", "Holmium", "Lanthanum",
        "Lutetium", "Neodymium", "Organorare earth metal compounds", "Phosphors", "Praseodymium", "Promethium",
        "Rare earth borides", "Rare earth fluorides", "Rare earth halides", "Rare earth industry",
        "Rare earth industry--Accidents", "Rare earth ions", "Rare earth ions--Spectra", "Rare earth lasers",
        "Rare earth metal alloys", "Rare earth metal catalysts", "Rare earth metal compounds",
        "Rare earth metal compounds--Magnetic properties", "Rare earth metal compounds--Thermal properties",
        "Rare earth metals", "Rare earth metals--Magnetic properties", "Rare earth metals--Magnetic properties",
        "Rare earth metals--Metallurgy", "Rare earth metals--Spectra", "Rare earth nitrates", "Rare earth nuclei",
        "Rare earth oxide thin films", "Rare earth phosphates", "Rare earths", "Rare earth-silicon-iron-aluminum alloys",
        "Rare earths--Magnetic properties", "Rare earths--Spectra", "Samarium", "Scandium", "Terbium", "Thulium",
        "Ytterbium", "Yttrium"]
    },
    plastics_and_synthetic_fibers: {
      title: "Plastics & Synthetic Fibers",
      description: "Plastics encompass a wide range of synthetic and semi-synthetic materials created from large repeating molecules called polymers. The Institute’s collections include a wide variety of materials documenting the history of the study of polymers, the development of plastics, the plastic industry, synthetic fibers, microplastics, works depicting or created by early pioneers of the field, and other related topics. Browse the digitized materials in this digital collection to learn more about plastics and synthetic fibers from the lab to your living room."
      subject: ["Acrylic fiber industry", "Acrylic resin industry", "Acrylic resins", "Advertising--Plastics", "Bakelite",
       "Biodegradable plastics", "Celluloid", "Dyes and dyeing--Plastics", "Injection molding of plastics", "Microplastics",
       "Plastic films", "Plastic kitchen utensils", "Plastic tableware", "Plastic tiles", "Plastic toys", "Plasticizer industry",
        "Plasticizers", "Plastics", "Plastics in medicine", "Plastics in packaging,", "Plastics industry and trade",
        "Plastics machinery industry", "Plastics--Analysis", "Plastics--Coloring", "Plastics--Deterioration",
        "Plastics--Extrusion", "Plastics--Handbooks, manuals, etc.", "Plastics--Molding", "Plastics--Molds",
        "Plastics--Periodicals", "Plastics--Research", "Plastics--Testing", "Polyethylene", "Polyethylene terephthalate",
        "Polyolefins", "Polypropylene", "Polypropylene fibers", "Polystyrene", "Polyvinyl chloride", "Polyvinyl chloride industry",
        "Styrene", "Synthetic fabrics", "Synthetic products", "Thermoplastic composites", "Thermoplastics", "Thermosetting composites",
        "Dyes and dyeing--Nylon", "Dyes and dyeing--Rayon", "Nylon", "Rayon", "Rayon industry and trade", "Synthetic fabrics",
        "Synthetic products", "Textile fibers, Synthetic", "Thermosetting composites", "Polytef]
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

  def redirect_path_type?
    definition.has_key?(:path)
  end

  def path
    if redirect_path_type?
      definition[:path]
    else
      # Hard-coding this, just for efficiency, instead of:
      # Rails.application.routes.url_helpers.featured_topic_path(slug)
      "focus/#{slug}"
    end
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
    "featured_topics/#{category_key}_2x.jpg"
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
