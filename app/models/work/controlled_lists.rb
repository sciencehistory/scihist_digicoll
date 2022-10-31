# Constants for various controlled lists for Work attributes.
#
# _Removing_ values from here may require data migration in your existing db.
#
# ## Display lables via i18n
# These are the values actually stored in the DB. Display-translated values can be
# provided via a poorly documented built-in feature of Rails i18n.
#
# If you put an I18n value in your locale file (eg config/locales/en.yml) at:
#     activerecord:
#       attributes:
#         work/format:
#           image: "Really great image"
#
# Then you can look it up with Work.human_attribute_name("format.image"). It even
# does some superclass lookup for you if you have an inheritance hieararchy.
#
# ## Some lists elsewhere
# Controlled values for specific sub-model classes (like Creator) can be found
# within them, not here. This is only for primitive attributes on Work. (But should
# we move sub-model lists here too?)
class Work
  class ControlledLists
    # from https://github.com/sciencehistory/chf-sufia/blob/master/config/authorities/resource_types.yml
    # Note these had corresponding RDF value URIs listed originally, although they weren't used
    # by our sufia app either.
    FORMAT = %w{image mixed_material moving_image physical_object sound text}.freeze

    GENRE = [
      'Advertisements',
      'Artifacts',
      'Business correspondence',
      'Catalogs',
      'Charts, diagrams, etc',
      'Chemistry sets',
      'Clothing and dress',
      'Drawings',
      'Electronics',
      'Encyclopedias and dictionaries',
      'Engravings',
      'Ephemera',
      'Etchings',
      'Figurines',
      'Glassware',
      'Handbooks and manuals',
      'Illustrated works',
      'Illustrations',
      'Implements, utensils, etc.',
      'Lithographs',
      'Manuscripts',
      'Maps',
      'Medical instruments and apparatus',
      'Molecular models',
      'Money',
      'Negatives (Photographs)',
      'Oral histories',
      'Paintings',
      'Pamphlets',
      'Personal correspondence',
      'Pesticides',
      'Photographs',
      'Photomechanical prints',
      'Plastics',
      'Portraits',
      'Postage stamps',
      'Postcards',
      'Press releases',
      'Prints',
      'Publications',
      'Rare books',
      'Records (Documents)',
      'Sample books',
      'Scientific apparatus and instruments',
      'Slides',
      'Specimens',
      'Stereographs',
      'Textile fabrics',
      'Vessels (Containers)',
      'Video Recordings',
      'Woodcuts'
    ].freeze

    DEPARTMENT = [
      'Archives',
      'Center for Oral History',
      'Museum',
      'Library',
    ].freeze

    FILE_CREATOR = [
      'Auerbach, Jahna',
      'Brown, Will',
      'Center for Oral History',
      'Conservation Center for Art & Historic Artifacts',
      'DiMeo, Michelle',
      'George Blood Audio LP',
      'Kativa, Hillary',
      'Lockard, Douglas',
      'Lu, Cathleen',
      'Miller, Megan',
      'Muhlin, Jay',
      'Newhouse, Sarah',
      'Pinkney, Annabel',
      'Reflex Technologies',
      'The University of Pennsylvania Libraries',
      'Tobias, Gregory',
      'Voelkel, James',
    ]

    EXHIBITION = [
      "Age of Alchemy",
      "Books of Secrets",
      "Elemental Matters",
      "ExhibitLab",
      "Inspiring Youth in Chemistry",
      "Lobby 2017",
      "Making Modernity",
      "Marvels and Ciphers",
      "Molecules That Matter",
      "Object Explorer",
      "Science at Play",
      "Second Skin",
      "Sensing Change",
      "The Alchemical Quest",
      "The Sky's the Limit",
      "The Whole of Nature and the Mirror of Art",
      "Things Fall Apart",
      "Transmutations"
    ]
  end
end
