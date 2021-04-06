class WorkManageOralHistoryAvailableByRequest < ViewModel
  valid_model_type_names "Work"

  alias_method :work, :model

  def display
    render 'admin/works/oral_history_available_by_request', model: model, view: self
  end


  def private_asset_members
    @private_asset_members ||= work.members.find_all { |m| m.kind_of?(Asset) && !m.published? }
  end

  # only show the panel to change by-request status if we have
  # non-published items, OR if it's already set to something other than
  # 'off'
  def allow_change_by_request?
    private_asset_members.present? || (work.oral_history_content && !work.oral_history_content.available_by_request_off?)
  end
end
