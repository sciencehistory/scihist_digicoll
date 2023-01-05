module AdminMenuHelper
  def admin_dropdown_for_work(work, labelled_by_id:)
    options = [
      maybe_enabled_dropdown_item(
        can?(:update, work),
        'Edit Metadata',
        edit_admin_work_path(work)
      ),

      maybe_enabled_dropdown_item(
        can?(:view, work),
        'Members',
        admin_work_path(work, anchor: "nav-members")
      ),
      
      maybe_enabled_dropdown_item(
        can?(:destroy, work),
        "Demote to Asset",
        demote_to_asset_admin_work_path(work),
        method: :put,
        data: { confirm: "All work metadata on #{work.title} will be lost, this is not reversible. Are you sure?" }
      ),
      
      maybe_enabled_dropdown_item(
        can?(:destroy, work),
        'Delete', [:admin, work],
        method: :delete,
        data: { confirm: "Delete Work '#{work.title}'?" }
      )
    ].compact

    content_tag(:div, class: "dropdown-menu dropdown-menu-right", :"aria-labelledby" => labelled_by_id) do
      safe_join(options)
    end
  end

  def admin_dropdown_for_asset(asset, labelled_by_id:)
    options = [
      maybe_enabled_dropdown_item(
        can?(:update, asset),
        'Edit', edit_admin_asset_path(asset)),
      maybe_enabled_dropdown_item(
        can?(:update, asset),
        'Convert to child work', convert_to_child_work_admin_asset_path(asset), method: "put"),
      maybe_enabled_dropdown_item(
        can?(:destroy, asset),
        'Delete', [:admin, asset], method: :delete, data: { confirm: "Delete Asset '#{asset.title}'?" })
    ].compact

    content_tag(:div, class: "dropdown-menu dropdown-menu-right", :"aria-labelledby" => labelled_by_id) do
      safe_join(options)
    end
  end

  def admin_dropdown_for_collection(collection, labelled_by_id:)
    options = [
      maybe_enabled_dropdown_item(
        can?(:update, collection),
        'Edit', edit_admin_collection_path(collection)
      ),
      maybe_enabled_dropdown_item(
        can?(:destroy, collection),
        'Delete', [:admin, collection], method: :delete, data: { confirm: "Delete collection '#{collection.title}'?" }
      )
    ].compact

    content_tag(:div, class: "dropdown-menu dropdown-menu-right", :"aria-labelledby" => labelled_by_id) do
      safe_join(options)
    end
  end

  private

  # A convenient way to enable or disable these dropdown links based on permissions.
  def maybe_enabled_dropdown_item(condition, body, url, html_options={})
    if condition
      link_to(body, url, html_options.merge({class: "dropdown-item"}))
    else
      link_to(body, "",  html_options.merge({class: "dropdown-item disabled"}))
    end
  end
end
