# frozen_string_literal: true
class SortedTableHeaderLinkComponent < ApplicationComponent     
  def initialize(column_title:, sort_field:, table_sort:, extra_params: {})

      # Info about the link we're about to render:
      # Column title
      @column_title = column_title
      # Associated sort field
      @sort_field = sort_field
      raise ArgumentError.new("Missing arguments: column_title or sort field") unless @column_title.present? && @sort_field.present?

      # Info about the current state of the sorted table:
      # What column is the table *currently* ordered by?
      @table_sort_field = table_sort[:field]
      # Is the table  *currently* sorted in ascending or descending order?
      # (should be one of 'asc' or 'desc')
      @table_sort_order = table_sort[:order]

      raise ArgumentError.new("Missing table_sort_field") unless @table_sort_field.present?
      raise ArgumentError.new("table_sort_order needs to be either 'asc' or 'desc' ") unless ['asc', 'desc'].include? @table_sort_order


      # Any extra params to tack on to the end of the URL, to maintain the state of the page:
      # e.g. page number, a search phrase, anything else you need:
      @extra_params = extra_params
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
end
