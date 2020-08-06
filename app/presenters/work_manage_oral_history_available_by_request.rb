class WorkManageOralHistoryAvailableByRequest < ViewModel
  valid_model_type_names "Work"

  alias_method :work, :model

  def display
    render 'admin/works/oral_history_available_by_request', model: model, view: self
  end


  def private_asset_members
    work.members.find_all { |m| m.kind_of?(Asset) && !m.published? }
  end
end
