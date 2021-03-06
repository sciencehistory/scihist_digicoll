module AdminMenuHelper
  def admin_dropdown_for_work(work, labelled_by_id:)
    options = [
      link_to('Edit Metadata', edit_admin_work_path(work), class: "dropdown-item"),
      link_to('Members', admin_work_path(work, anchor: "nav-members"), class: "dropdown-item"),
      link_to("Demote to Asset",
                demote_to_asset_admin_work_path(work),
                method: "put",
                class: "dropdown-item",
                data: { confirm: "All work metadata on #{work.title} will be lost, this is not reversible. Are you sure?" }),
      (link_to('Delete', [:admin, work], method: :delete, data: { confirm: "Delete Work '#{work.title}'?" }, class: "dropdown-item") if can?(:destroy, work))
    ].compact

    content_tag(:div, class: "dropdown-menu dropdown-menu-right", :"aria-labelledby" => labelled_by_id) do
      safe_join(options)
    end
  end

  def admin_dropdown_for_asset(asset, labelled_by_id:)
    options = [
      link_to('Edit', edit_admin_asset_path(asset), class: "dropdown-item"),
      link_to('Convert to child work', convert_to_child_work_admin_asset_path(asset), method: "put", class: "dropdown-item"),
      (link_to('Delete', [:admin, asset], method: :delete, data: { confirm: "Delete Asset '#{asset.title}'?" }, class: "dropdown-item") if can?(:destroy, asset))
    ].compact

    content_tag(:div, class: "dropdown-menu dropdown-menu-right", :"aria-labelledby" => labelled_by_id) do
      safe_join(options)
    end
  end
end
