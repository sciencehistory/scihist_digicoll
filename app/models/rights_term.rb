# Not ActiveRecord/DB-persisted, just a utility method for working with "rights statement"
# data from a YML file.
#
# Right now we don't do i18n, labels are just hard-coded in YAML. But we easily could.
#
#
#     term = RightsTerm.find("http://rightsstatements.org/vocab/InC-OW-EU/1.0/")
#     term.id
#     term.category
#     term.short_label_html
#
#     RightsTerm.collection_for_select
#
# If you ask to #find an  ID that isn't defined, rather than raise we return
# a null object that just has empty values.
#
#     null_term = RightsTerm.find("no_such_term")
#     null_term.id # => "no_such_term"
#     null_term.label # => nil
#     null_term.category # => nil
#
class RightsTerm
  class NotFound < ArgumentError ; end

  YAML_SOURCE_PATH = Rails.root.join("config/data/rights_terms.yml").to_s


  attr_reader :id, :label, :category, :short_label_html, :short_label_inline,
    :icon_alt, :pictographs

  def initialize(hash)
    @id                 = hash["id"]
    @label              = hash["label"]
    @category           = hash["category"]
    @short_label_html   = hash["short_label_html"]
    @icon_alt           = hash["icon_alt"]
    @pictographs        = hash["pictographs"] || []

    @short_label_inline = short_label_html.try { |str| str.gsub("<br>", " ") }
  end


  # If id is not found, it returns a "Null object" where all values are nil/empty.
  def self.find(id)
    terms_by_id[id] || (new({"id" => id}))
  end

  def self.all_ids
    terms_by_id.keys
  end

  def self.all
    terms_by_id.values
  end

  # Array of label-id pairs, useful for passing to helpers for creating select menus
  # on forms.
  def self.collection_for_select
    all_ids.collect {|id| [find(id).label, id] }
  end

  # shortcut for this especially popular one
  def self.label_for(id)
    find(id).label
  end

  private

  def self.terms_by_id
    # from the array of term hashes, to an array of [id, term_hash], that
    # can be turned into a hash keyded on `id`, by using Array#to_h
    @terms_by_id ||= YAML.load_file(YAML_SOURCE_PATH)["terms"].collect do |hash|
                      [hash["id"], self.new(hash)]
                    end.to_h
  end

end

