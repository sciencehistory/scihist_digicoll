# Front-end controller to list public collections.
class CollectionsListController < ApplicationController
  DEPARTMENT_FILTERS = Work::ControlledLists::DEPARTMENT.collect { |d| [d.parameterize, d] }.sort_by {|param, label| label }.to_h.freeze

  def index
    @collections = Collection.
      where("published = true").
      not_jsonb_contains(department: Collection::DEPARTMENT_EXHIBITION_VALUE).
      order(:title).
      includes(:leaf_representative)

    if params[:department_filter]
      @collections = @collections.where("json_attributes ->> 'department' = ?", DEPARTMENT_FILTERS[params[:department_filter]])
    end
  end
end
