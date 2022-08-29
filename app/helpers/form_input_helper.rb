# We could have done these as methods on a custom local SimpleForm::FormBuilder class?
# But for now we use ugly ugly helpers, first arg is always form builder.
#
# These also could arguably have been done somewhat more readably with template partials
# (and in some cases may call out to render partials?), but ruby methods are both somewhat
# more performant (especially in dev mode), and more clear to add parameterization via arguments to
# (`locals` in partials are confusing and lead to confusing ERB code for defaults etc.)
#
# Arguably we should extract some of these to helper classes. Rails does not provide
# a great architecture for complex view generation code.
module FormInputHelper

  # We have a variety of inputs that are a category (with a select input)
  # followed by a value. They always map to custom AttrJson::Model classes, which
  # this helper assumes -- and gets that class for reflection from builder.object.class.
  #
  # By default the attribute names are assumed to be :category and :value,
  # but you can pass in others.
  #
  # You must pass in valid category db values in category_list. (Future, some
  # kind of introspection to default maybe)
  #
  # There is some translation of values to human-displayable labels, using i18n.
  # For instance, if your class is Work::ExternalID, attribute is `category`, and one
  # value is "object_id", you can provide an i18n key at:
  # `activemodel.enum_values.work/external_id.category.object_id`
  #
  # @example
  #         <%= f.repeatable_attr_input(:external_id) do |sub_form| %>
  #            <%= category_and_value(sub_form) %>
  #         <% end %>
  #
  # FUTURE:
  # * Extract to helper object?
  # * I18n right now doesn't use superclasses, we could use ActiveModel
  #   human_attribute_name as a guide, and make our own human_value_name or something
  #   that is more powerful.
  def category_and_value(builder,
                         category_key: :category,
                         value_key: :value,
                         category_list:,
                         input_data_attributes: {})
    model = builder.object

    category_list = vocab_collection_options(model: model, attribute_name: category_key, value_list: category_list)

    content_tag("div", class: "form-row category-and-value") do
      content_tag("div", class: "col-left category") do
        builder.input category_key, collection: category_list, label: false, include_blank: false
      end +
      content_tag("div", class: "col-sm value") do
        builder.input value_key, label: false, input_html: { data: input_data_attributes }
      end
    end
  end

  # We have controlled vocabularies used in our metadata. We want to create a UI input
  # that lets staff choose one of these values. These UI inputs need to have the internal value
  # and the human label.
  #
  # This method returns a hash whose key is human labels and values are internal codes, suitable
  # for use with a lot of Rails collection input helpers.
  #
  # If the *current* value does not exist -- we still add it on top, so the input can
  # display the current value. This includes a blank value! Since we add blank value
  # ourselves only if necessary, `allow_blank: false` should normally be passed to rails
  # collection input helper.
  #
  # The human labels are looked up optionally using rails i18n, via #vocab_value_human_name
  #
  def vocab_collection_options(model:, attribute_name:, value_list:)
    model_class = model.class

    # If existing value (which may be nil) is not in category list, add it to front.
    existing_value = model.send(attribute_name)
    unless value_list.include?(existing_value)
      value_list = [existing_value] + value_list
    end

    # Turn category list into values and human labels, using i18n or rails humanizing.
    value_list = value_list.collect do |key|
      human_value = vocab_value_human_name(model_class: model_class, attribute_name: attribute_name, value: key)

      [human_value, key]
    end.to_h
  end

  # We have controllfed vocabularies used in our metadata. Eg creator category
  # might be `contributor`, `creator_of_work`, `editor`, .... We want to translate
  # to a human-presentable name .
  #
  # * If value is nil or blank, just return itself
  #
  # * We first try to use I18n lookup for `activemodel.enum_values.[model class i18n key].[attribute].[value]
  #   * I18n keys are a bit weird, trying to follow Rails convention.
  #     For instance, if your class is Work::ExternalID, attribute is `category`, and one
  #     value is "object_id", you can provide an i18n key at:
  #        `activemodel.enum_values.work/external_id.category.object_id`
  #
  # * If no such I18n key is defined, we just default to calling #humanize on the value
  #
  def vocab_value_human_name(model_class:, attribute_name:, value:)
    if value.blank?
      value
    elsif model_class.respond_to?(:model_name)
      I18n.t(value,
        scope: "activemodel.enum_values.#{model_class.model_name.i18n_key}.#{attribute_name}",
        default: value.humanize)
    else
      value.humanize
    end
  end
end
