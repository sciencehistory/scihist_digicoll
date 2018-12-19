module AdminMenuHelper
  def admin_dropdown_for_work(work, labelled_by_id:)
    content_tag(:div, class: "dropdown-menu dropdown-menu-right", :"aria-labelledby" => labelled_by_id) do
      safe_join([
        link_to('Edit Metadata', edit_work_path(work), class: "dropdown-item"),
        link_to('Members', members_for_work_path(work), class: "dropdown-item"),
        link_to('Delete', work, method: :delete, data: { confirm: "Delete Work '#{work.title}'?" }, class: "dropdown-item")
      ])
    end
  end

  def admin_dropdown_for_asset(asset, labelled_by_id:)
    content_tag(:div, class: "dropdown-menu dropdown-menu-right", :"aria-labelledby" => labelled_by_id) do
      safe_join([
        link_to('Delete', asset, method: :delete, data: { confirm: "Delete Asset '#{asset.title}'?" }, class: "dropdown-item")
      ])
    end
  end
end
