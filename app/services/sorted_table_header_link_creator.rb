class SortedTableHeaderLinkCreator
  def initialize(path:, controller:, current_sort_field:nil, current_sort_order:nil, extra_params: {})
    @path = path
    @controller = controller
    @current_sort_field = current_sort_field
    @current_sort_order = current_sort_order
    @extra_params = extra_params
  end

  def sort_link(link_field:, title:)
    @controller.view_context.link_to(
      "#{title} #{sort_arrow if switching_to?(link_field)}" ,
      sort_column_path( link_field: link_field)
    )
  end

private
  def sort_column_path(link_field:)
    kwargs = {
        sort_field: link_field,
        sort_order: (reversed_sort_order if switching_to? link_field)
    }
    kwargs.merge!(@extra_params)
    @controller.send @path, **kwargs
  end

  def switching_to?(field)
    field == @current_sort_field
  end
  
  def sort_arrow
    (@current_sort_order == "asc") ?  "▲": "▼"
  end

  def reversed_sort_order
    (@current_sort_order == "asc") ? "desc" : "asc"
  end
end
