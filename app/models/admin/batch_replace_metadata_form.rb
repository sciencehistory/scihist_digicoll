# Backs the admin "batch replace metadata" feature: given a Work metadata field (one of
# ALLOWED_FIELDS below), an old value, and a new value, finds all Works whose field has
# a value that exactly matches the old value, and can replace it with the new value
# across all of them.
#
#     form = Admin::BatchReplaceMetadataForm.new(field_name: "creator", old_value: "Foo Bar", new_value: "Baz")
#     form.matching_works        # => #<ActiveRecord::Relation [#<Work ...>, ...]>
#     form.matching_work_count   # => 12
#     form.replace!              # => true, and all matching works are now saved with the replacement made
#
# If replace! returned false, then errors in form.errors
#
class Admin::BatchReplaceMetadataForm
  include ActiveModel::Model

  # The Work metadata fields available for this feature. For safety, field only
  # allowed if it's listed here. If new fields are added to work, add them here.
  #
  # If a field is not a simple scalar but a nested/compound field, the value is the
  # key to look up in sub-record. We can only choose ONE of them as the target, tool
  # not sophisticated enough to do more than that at present.
  ALLOWED_FIELDS = {
    additional_title:    nil,
    external_id:         :value,
    creator:             :value,
    place:               :value,
    medium:              nil,
    extent:              nil,
    language:            nil,
    description:         nil,
    provenance:          nil,
    inscription:         :text,
    subject:             nil,
    series_arrangement:  nil,
    related_url:         nil,
    related_link:        :url,
    rights_holder:       nil,
    additional_credit:   :name,
    digitization_funder: nil,
    file_creator:        nil,
    admin_note:          nil
  }.freeze

  attr_accessor :field_name, :old_value, :new_value

  validates :old_value, presence: true
  validates :new_value, presence: true
  validate :field_name_must_be_a_known_field

  # ALLOWED_FIELDS as [label, name] pairs sorted by label, ready for use with
  # `options_for_select` in the field-selection form.
  def self.field_options
    ALLOWED_FIELDS.keys.map { |name| [Work.human_attribute_name(name), name] }.sort_by(&:first)
  end

  # Human-readable label for the currently-selected field.
  def field_label
    Work.human_attribute_name(field_name)
  end

  # All Works whose configured field exactly matches `old_value`, found with a database
  # query (via AttrJson's `jsonb_contains`) rather than loading every Work.
  #
  # @return [ActiveRecord::Relation<Work>]
  def matching_works
    return Work.none unless valid?
    @matching_works ||= Work.jsonb_contains(contains_key => old_value)
  end

  def matching_work_count
    matching_works.count
  end

  # Actually performs the replacement on all matching works, saving each one, and
  # scheduling solr reindexing for them. All-or-nothing: if any work would be left
  # invalid by the replacement, nothing is saved.
  #
  # @return [Boolean] true on success; on failure, #errors has details, and nothing was changed.
  def replace!
    return false unless valid?

    updated_work_ids = []

    Kithe::Indexable.index_with(disable_callbacks: true) do
      Work.transaction do
        matching_works.find_each do |work|
          replace_value!(work)

          unless work.valid?
            errors.add(:base, "#{work.title} (#{work.friendlier_id}): #{work.errors.full_messages.join(', ')}")
            raise ActiveRecord::Rollback
          end

          work.save!
          updated_work_ids << work.id
        end
      end
    end

    return false if errors.present?

    updated_work_ids.each_slice(Kithe.indexable_settings.batching_mode_batch_size) do |ids|
      ReindexWorksJob.perform_later(ids)
    end

    true
  end

  private

  # nil for a plain field, or the sub-attribute name to search/replace within, for a
  # field whose value is (an array of) AttrJson::Model.
  def key_path
    ALLOWED_FIELDS[field_name.to_sym]
  end

  def nested_model?
    key_path.present?
  end

  # The `jsonb_contains` attribute key for the selected field (see
  # AttrJson::Record::QueryScopes#jsonb_contains) -- just the field name, or, for a
  # nested-model field, "field_name.key_path" so we can match on the nested key_path
  # attribute's value, wherever it is in an array of those nested models.
  def contains_key
    nested_model? ? "#{field_name}.#{key_path}" : field_name.to_s
  end

  # Mutates (does not save) `work`, replacing an exact old_value match with new_value
  # in the selected field. attr_json detects in-place mutation of array/nested values
  # just fine, so there's no need to re-assign the attribute after mutating it.
  def replace_value!(work)
    if nested_model?
      Array(work.public_send(field_name)).each do |element|
        element.public_send("#{key_path}=", new_value) if element.public_send(key_path) == old_value
      end
    else
      value = work.public_send(field_name)
      if value.is_a?(Array)
        value.map! { |v| v == old_value ? new_value : v }
      else
        work.public_send("#{field_name}=", new_value) if value == old_value
      end
    end
  end

  def field_name_must_be_a_known_field
    errors.add(:field_name, "is not a recognized field") unless field_name.present? && ALLOWED_FIELDS.key?(field_name.to_sym)
  end
end
