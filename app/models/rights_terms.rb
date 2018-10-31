# Not ActiveRecord/DB-persisted, just a utility method for working with "rights statement"
# data from a YML file.
#
# In our origial chf-sufia app, this was a cover on a YAML file used by questoning_authority
# too. But we kind of had to fight with qa to give this the functionality and performance we needed,
# and didn't really need QA for anything here, so have extracted into purely a custom class.
#
# The API inherited from original implementation is a bit hacky (mostly just global utility methods,
# no actual model objects), but it's good enough for now.
#
# Right now we don't do i18n, labels are just hard-coded in YAML. But we easily could.
#
#     RightsTerms.category_for("http://rightsstatements.org/vocab/InC-OW-EU/1.0/")
#     RightsTerms.short_label_html_for("http://rightsstatements.org/vocab/InC-OW-EU/1.0/")
#     RightsTerms.metadata_for("http://rightsstatements.org/vocab/InC-OW-EU/1.0/")
class RightsTerms

  def initialize(yaml_file_path = Rails.root.join("config/data/rights_terms.yml"))
    @yaml_file_path = yaml_file_path
  end

  def all_ids
    @all_ids ||= terms_by_id.keys
  end

  # Array of label-id pairs, useful for passing to helpers for creating select menus
  # on forms.
  def collection_for_select
    all_ids.collect {|id| [label_for(id), id] }
  end

  def label_for(id)
    metadata_for(id).try { |h| h["label"] }
  end

  def category_for(id)
    metadata_for(id).try { |h| h["category"] }
  end

  def short_label_html_for(id)
    metadata_for(id).try { |h| h["short_label_html"] }
  end

  def metadata_for(id)
    terms_by_id[id]
  end

  # A global/default instance of this object, a singleton-like
  # pattern, but we aren't enforcing only one object can exist.
  def self.global
    @global ||= self.new
  end

  # This weird code was what I ame up with to succesfully use Rails
  # 'delegate' to the #global class method containing a global instance.
  class << self
    delegate :all_ids, :collection_for_select, :metadata_for, :category_for,
      :short_label_html_for, :label_for, to: :global
  end

  private

  def terms_by_id
    # from the array of term hashes, to an array of [id, term_hash], that
    # can be turned into a hash keyded on `id`, by using Array#to_h
    @terms_by_id ||= YAML.load(File.read(@yaml_file_path))["terms"].collect do |hash|
                      [hash["id"], hash]
                    end.to_h
  end

end
