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
                         category_list:)
    model_class = builder.object.class

    # If existing value (which may be nil) is not in category list, add it to front.
    existing_category_value = builder.object.send(category_key)
    unless category_list.include?(existing_category_value)
      category_list = [existing_category_value] + category_list
    end

    # Turn category list into values and human labels, using i18n or rails humanizing.
    category_list = category_list.collect do |key|
      value = if key.nil?
        key
      elsif model_class.respond_to?(:model_name) && key.present?
        I18n.t(key,
          scope: "activemodel.enum_values.#{model_class.model_name.i18n_key}.#{category_key}",
          default: key.humanize)
      else
        key.humanize
      end

      [value, key]
    end.to_h

    content_tag("div", class: "form-row category-and-value") do
      content_tag("div", class: "col-left category") do
        builder.input category_key, collection: category_list, label: false, include_blank: false
      end +
      content_tag("div", class: "col-sm value") do
        builder.input value_key, label: false
      end
    end
  end

end
