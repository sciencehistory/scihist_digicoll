class CollectionResultDisplay < ViewModel
  def display
    render "/view_models/index_result", model: model, view: self
  end
end
