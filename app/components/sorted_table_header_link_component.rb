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
  # @return [SortedTableHeaderLinkComponent::LinkMaker] a LinkMaker object whose link method returns a SortedTableHeaderLinkComponent with prepopulated fields.
  def self.link_maker(params:, table_sort_field_key: :sort_field, table_sort_order_key: :sort_order)
    raise ArgumentError.new("Unpermitted params") unless params.permitted?
    self::LinkMaker.new(
      params: params,
      table_sort_field_key: table_sort_field_key,
      table_sort_order_key: table_sort_order_key
    )
  end

  # @param [String] column_title The text of the link; the column title as displayed to the user.
  # @param [String] sort_field the new sort field that will be used if a user clicks the link.
  # @param [String] table_sort_field the current sort field of the table.
  # @param [String] table_sort_order the current sort order of the table.
  # @param [String] table_sort_field_key the key in params identifying the current sort order of the table.
  # @param [String] table_sort_order_key the key in params identifying the current sort order of the table.
  # @param [Hash] other_params any and all extra paramaters to add to the link.
  def initialize(column_title:, sort_field:,
    table_sort_field:, table_sort_order:,
    table_sort_field_key: :sort_field, table_sort_order_key: :sort_order,
    other_params:)
    unless column_title.present? && sort_field.present?
      raise ArgumentError.new("Missing arguments: column_title or sort field")
    end
    unless table_sort_order.in? ['asc', 'desc']
      raise ArgumentError.new("Sort order needs to be asc or desc")
    end
    @column_title = column_title
    @sort_field = sort_field
    @table_sort_field = table_sort_field
    @table_sort_order = table_sort_order
    @table_sort_field_key = table_sort_field_key
    @table_sort_order_key = table_sort_order_key
    @other_params = other_params
  end

  def call
    link_to sort_column_title, sort_column_path
  end


  def sort_column_path
    # if we're generating a link for the currently sorted-upon field which is currently
    # `asc`, we reverse it to `desc` in the selected sort -- otherwise the click is always requesting `asc`,
    # our default.
    new_table_sort_order = if @sort_field == @table_sort_field && @table_sort_order == 'asc'
      'desc'
    else
      'asc'
    end

    url_param_hash = @other_params || {}
    url_param_hash[@table_sort_field_key] = @sort_field
    url_param_hash[@table_sort_order_key] = new_table_sort_order

    url_for url_param_hash
  end

  def sort_column_title
    "#{@column_title}#{sort_arrow if @sort_field == @table_sort_field}"
  end

  def sort_arrow
    (@table_sort_order == "asc") ? " ▲" : " ▼"
  end

  # Nested class whose #link method returns a SortedTableHeaderLinkComponent.
  # This class effectively stores everything we need to know about the table
  # that allows us to easily create links later on.
  class LinkMaker
    # @param [ActionController::Parameters] params the permitted params from the controller
    # @param [Symbol] table_sort_field_key the current sort field of the table.
    # @param [Symbol] table_sort_order_key the current sort order of the table.
    def initialize(params:, table_sort_field_key: :sort_field, table_sort_order_key: :sort_order)
      @table_sort_field_key = table_sort_field_key
      @table_sort_order_key = table_sort_order_key
      @table_sort_field =     params[table_sort_field_key]
      @table_sort_order =     params[table_sort_order_key]
      @other_params     =     params.except(table_sort_field_key, table_sort_order_key)
    end

    # @param [String] column_title The text of the link; the column title as displayed to the user.
    # @param [String] sort_field the new sort field that will be used if a user clicks the link.
    # @return [SortedTableHeaderLinkComponent] a link component to render in the template.
    def link(column_title:, sort_field:)
      SortedTableHeaderLinkComponent.new(
        column_title: column_title, sort_field: sort_field,
        # we already know about the rest of the table state:
        table_sort_field:     @table_sort_field,
        table_sort_order:     @table_sort_order,
        table_sort_field_key: @table_sort_field_key,
        table_sort_order_key: @table_sort_order_key,
        other_params:         @other_params
      )
    end
  end
end
