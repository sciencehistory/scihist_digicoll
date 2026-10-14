# Backs the admin "batch replace metadata" feature: given a Work metadata field (one of
# ALLOWED_FIELDS below), an old value, and a new value, finds all Works whose field has
# a value that exactly matches the old value, and can replace it with the new value
# across all of them.
#
# Scoped to a current_user's cart.
#
#     form = Admin::BatchReplaceMetadataForm.new(current_user: current_user, form_params: { field_name: "creator.value", old_value: "Foo Bar", new_value: "Baz" })
#     form.matching_works        # => #<ActiveRecord::Relation [#<Work ...>, ...]>, works in current_user's Cart only
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
  # A nested/compound field is "attribute.sub_attribute" (as in jsonb_contains), and only that sub-attribute is searched/replaced.
  ALLOWED_FIELDS = %w[
    additional_title
    external_id.value
    creator.value
    place.value
    medium
    extent
    language
    description
    provenance
    inscription.text
    subject
    series_arrangement
    related_url
    related_link.url
    rights_holder
    additional_credit.name
    digitization_funder
    file_creator
    admin_note
    genre
    format
    rights
    physical_container.box
    physical_container.folder
  ].freeze

  attr_accessor :field_name, :old_value, :new_value
  attr_reader :current_user

  validates :old_value, presence: true
  validates :new_value, presence: true
  validate :field_name_must_be_a_known_field

  def initialize(current_user:, form_params: {})
    @current_user = current_user
    super(form_params)
  end

  # ALLOWED_FIELDS as [label, name] pairs sorted by label, ready for use with
  # `options_for_select` in the field-selection form.
  def self.field_options
    ALLOWED_FIELDS.map { |name| [field_label(name), name] }.sort_by(&:first)
  end

  # The attribute's label. We add a sub-attribute to label only if main attribute
  # was in our list more than once!
  def self.field_label(field_name)
    attribute, sub_attribute = field_name.to_s.split(".")
    attribute_used_count = ALLOWED_FIELDS.count { |name| name.split(".").first == attribute }

    attribute_used_count > 1 ? "#{Work.human_attribute_name(attribute)}: #{sub_attribute.humanize}" : Work.human_attribute_name(attribute)
  end

  # Fields with a short controlled list, as { field_name => [[label, value], ...] }; the form shows select menus for these.
  def self.controlled_values
    {
      genre:  Work::ControlledLists::GENRE.map { |v| [v, v] },
      format: Work::ControlledLists::FORMAT.map { |v| [Work.human_attribute_name("format.#{v}"), v] },
      rights: RightsTerm.collection_for_select
    }
  end

  # Human-readable label for the currently-selected field.
  def field_label
    self.class.field_label(field_name)
  end

  # How many Works are in current_user's Cart in total -- the universe this feature
  # searches/replaces within.
  def cart_work_count
    current_user.works_in_cart.count
  end

  # Works in current_user's Cart whose configured field exactly matches `old_value`,
  # found with a database query (via AttrJson's `jsonb_contains`) rather than loading
  # every Work in the Cart.
  #
  # @return [ActiveRecord::Relation<Work>]
  def matching_works
    return Work.none unless valid?
    @matching_works ||= current_user.works_in_cart.jsonb_contains(field_name => old_value)
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

    Rails.logger.info("#{self.class.name}: #{current_user.email} changed field `#{field_name}` from `#{old_value}` to `#{new_value}` in #{updated_work_ids.count} works: #{updated_work_ids.join(',')}")

    updated_work_ids.each_slice(Kithe.indexable_settings.batching_mode_batch_size) do |ids|
      ReindexWorksJob.perform_later(ids)
    end

    true
  end

  private

  # the Work attribute, eg "creator" for "creator.value", or for just "creator"
  def attribute_name
    field_name.split(".").first
  end

  # the sub-attribute of a nested model to search/replace, eg "value" for "creator.value"; nil for a plain field
  def sub_attribute
    field_name.split(".")[1]
  end

  def nested_model?
    sub_attribute.present?
  end

  # Mutates (does not save) `work`, replacing an exact old_value match with new_value
  # in the selected field. attr_json detects in-place mutation of array/nested values
  # just fine, so there's no need to re-assign the attribute after mutating it.
  def replace_value!(work)
    if nested_model?
      # a single nested model (eg physical_container) gets wrapped into an array here
      Array(work.public_send(attribute_name)).each do |element|
        element.public_send("#{sub_attribute}=", new_value) if element.public_send(sub_attribute) == old_value
      end
    else
      value = work.public_send(attribute_name)
      if value.is_a?(Array)
        value.map! { |v| v == old_value ? new_value : v }.uniq!
      else
        work.public_send("#{attribute_name}=", new_value) if value == old_value
      end
    end
  end

  def field_name_must_be_a_known_field
    errors.add(:field_name, "is not a recognized field") unless ALLOWED_FIELDS.include?(field_name)
  end
end
