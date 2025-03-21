# This controller (just used for #index) runs a Blacklight search for all works and collections specified in the params,
# and returns JUST the friendlier ids in the search results, in a JSON array.
class AllSearchResultIdsController < CatalogController
  before_action :authenticate_user! # need to be logged in

  configure_blacklight do |config|
    config.search_state_fields << :all_search_result_ids
  end

  # get search results from the solr index
  def index
    render json: all_ids_from_search
  end


  # TODO make this a POST request
  def add_to_cart
    Work.transaction do
      all_ids_from_search.each_slice(500) do |current_slice|
        result = ActiveRecord::Base.connection.execute(sql_insert(current_user, current_slice))
      end
    end
    render plain: "OK"

    # TODO: redirect to the correct page
  end

  private


  def search_service_context
    super.merge!(all_search_result_ids: 'true')
  end

  # no need to bulk-load works
  self.search_service_class =  Blacklight::SearchService

private
  # override two methods in CatalogController that would otherwise prevent us from returning json results.
  def catch_bad_request_headers
  end

  def catch_bad_format_param
  end

  #Return a set to make sure there are no duplicates...
  def all_ids_from_search
    Set.new(search_service.search_results['response']['docs'].map { |doc| doc['id'] })
  end

  def sql_insert (user, ids)
    """
    INSERT INTO cart_items
      (
        user_id,
        work_id,
        created_at,
        updated_at
      )
    SELECT #{current_user.id},
      the_id,
      now(),
      now()
    FROM   (
      SELECT kithe_models.id AS the_id
      FROM   kithe_models
      WHERE  friendlier_id IN ( #{ ids.map {|id| "'#{id}'"}.join(", ") } )
      AND    type = 'Work'
      AND    id NOT IN
        (
          SELECT work_id
          FROM   cart_items
          WHERE  user_id = #{current_user.id} ) ) AS foo
    """
  end


end