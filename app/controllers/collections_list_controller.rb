# Front-end controller to list public collections.
class CollectionsListController < ApplicationController
  DEPARTMENT_FILTERS = Work::ControlledLists::DEPARTMENT.collect { |d| [d.parameterize, d] }.sort_by {|param, label| label }.to_h.freeze

  def index
    @collections = Collection.
      where("published = true").
      order(:title).
      includes(:leaf_representative)

    if params[:department_filter]
      @collections = @collections.where("json_attributes ->> 'department' = ?", DEPARTMENT_FILTERS[params[:department_filter]])
    end

    @child_count_display_fetcher = ChildCountDisplayFetcher.new(@collections.collect(&:friendlier_id))
  end
end
