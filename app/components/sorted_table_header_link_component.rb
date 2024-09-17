# frozen_string_literal: true
#
# This component outputs a column title header link to use in our sortable admin pages.
#
# Example:
# <a href="/admin/collections?department=Library&sort_field=updated_at&sort_order=desc&title_or_id=some_search_phrase">Last Modified ▲</a>
#
# This class does *not* take care of searching or filtering the table;
# it's only in charge of creating the links.
#
# Controller method:
#   @link_maker = SortedTableHeaderLinkComponent.link_maker(
#     params:               collection_params, # the controller's permitted ActiveRecord params
#     table_sort_field_key: :sort_field,       # keys for looking up the table's current sort field in the above
#     table_sort_order_key: :sort_order,       # keys for looking up the table's current sort order (asc or desc)
#     extra_param_keys:     [:title_or_id]     # any extra parameters you want to tack on to the URL.
#   )
#
#
# Now, for each sortable column in the template, call @link_maker.link with the column info to render the actual title link:
#   render(@link_maker.link(column_title: "title",         sort_field: "title"     ))
#   render(@link_maker.link(column_title: "Created",       sort_field: "created_at"))
#   render(@link_maker.link(column_title: "Last Modified", sort_field: "updated_at"))

class SortedTableHeaderLinkComponent < ApplicationComponent

  # @param [ActionController::Parameters] params the permitted params from the controller
  # @param [Symbol] table_sort_field_key the current sort field of the table.
  # @param [Symbol] table_sort_order_key the current sort order of the table.
  # @param [Hash<Symbol>] extra_param_keys any extra parameter keys to tack on to the link.
  # @return [SortedTableHeaderLinkComponent::LinkMaker] a LinkMaker object whose link method returns a SortedTableHeaderLinkComponent with prepopulated fields.
  def self.link_maker(params:, table_sort_field_key:, table_sort_order_key:, extra_param_keys: [])
    raise ArgumentError.new("Unpermitted params") unless params.permitted?
    self::LinkMaker.new(
      params: params,
      table_sort_field_key: table_sort_field_key,
      table_sort_order_key: table_sort_order_key,
      extra_param_keys:     extra_param_keys
    )
  end

  # @param [String] column_title The text of the link; the column title as displayed to the user.
  # @param [String] sort_field the new sort field that will be used if a user clicks the link.
  # @param [String] table_sort_field the current sort field of the table.
  # @param [String] table_sort_order the current sort order of the table.
  # @param [Hash<String>] extra_params any extra parameters to tack on to the link.
  def initialize(column_title:, sort_field:, table_sort_field:, table_sort_order:, extra_params: {})
    @column_title = column_title
    @sort_field = sort_field
    raise ArgumentError.new("Missing arguments: column_title or sort field") unless @column_title.present? && @sort_field.present?
    @table_sort_field = table_sort_field
    @table_sort_order = table_sort_order
    raise ArgumentError.new("Sort order needs to be asc or desc") unless ['asc', 'desc'].include? @table_sort_order
    @extra_params = extra_params
  end

  def call
    link_to sort_column_title, sort_column_path
  end

  def sort_column_path
    url_for (
      {
        sort_field:   @sort_field,
        sort_order:   (reversed_sort_order if @sort_field == @table_sort_field)
      }.merge!(@extra_params)
    )
  end

  def sort_column_title
    "#{@column_title} #{sort_arrow if @sort_field == @table_sort_field}"
  end

  def sort_arrow
    (@table_sort_order == "asc") ? "▲" : "▼"
  end

  def reversed_sort_order
    (@table_sort_order == "asc") ? "desc" : "asc"
  end

  # Nested class whose #link method returns a SortedTableHeaderLinkComponent.
  class LinkMaker
    # @param [ActionController::Parameters] params the permitted params from the controller
    # @param [Symbol] table_sort_field_key the current sort field of the table.
    # @param [Symbol] table_sort_order_key the current sort order of the table.
    # @param [Hash<Symbol>] extra_param_keys any extra parameter keys to tack on to the link.
    def initialize(params:, table_sort_field_key:, table_sort_order_key:, extra_param_keys: [])
      # Look up the params using the keys we were given:
      @table_sort_field = params[table_sort_field_key]
      @table_sort_order = params[table_sort_order_key]
      @extra_params     = params.slice(*extra_param_keys).to_h
    end

    # @param [String] column_title The text of the link; the column title as displayed to the user.
    # @param [String] sort_field the new sort field that will be used if a user clicks the link.
    # @return [SortedTableHeaderLinkComponent] a link component to render in the template.
    def link(column_title:, sort_field:)
      SortedTableHeaderLinkComponent.new(
        column_title: column_title,
        sort_field:   sort_field,
        
        table_sort_field: @table_sort_field,
        table_sort_order: @table_sort_order,
        extra_params:     @extra_params,
      )
    end
  end
end
