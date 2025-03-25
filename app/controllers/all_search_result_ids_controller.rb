# This controller (just used for #add_to_cart) runs a Blacklight search for all works and collections specified in the params.
# and returns JUST the friendlier ids in the search results, in a JSON array.
class AllSearchResultIdsController < CatalogController
  before_action :authenticate_user! # need to be logged in

  configure_blacklight do |config|
    config.search_state_fields << :all_search_result_ids
  end


  # A CartItem doesn't contain a lot of data, so this goes quite quickly:
  def add_to_cart
    conn = ActiveRecord::Base.connection
    CartItem.transaction do
      all_ids_from_search.each_slice(500) do |ids|
        conn.execute(add_friendlier_ids_to_cart_sql(ids))
      end
    end
    redirect_back_or_to '/', allow_other_host: false
  end

  # tell AllSearchResultIdsBuilder to modify the solr params before connecting to solr
  def search_service_context
    super.merge!(all_search_result_ids: 'true')
  end

  # no need to bulk-load works; there could be thousands of them.
  self.search_service_class =  Blacklight::SearchService

  private

  # Careful - these may contain Kithe::Collection friendlier_ids, too.
  def all_ids_from_search
    search_service.search_results['response']['docs'].map { |doc| doc['id'] }
  end

  def add_friendlier_ids_to_cart_sql(friendlier_ids)
    friendlier_id_list = friendlier_ids.map {|id| "'#{id}'"}.join(",")
    """
    INSERT INTO cart_items
      (
        user_id, work_id, created_at, updated_at
      )
    SELECT #{ user_id }, cart_work_friendlier_id, now(), now()
    FROM   (
      SELECT kithe_models.id AS cart_work_friendlier_id
      FROM   kithe_models
      WHERE  friendlier_id IN ( #{ friendlier_id_list } )
      AND    type = 'Work'
      AND    id NOT IN
        (
          SELECT work_id
          FROM   cart_items
          WHERE  user_id = #{ user_id }
        )
    ) AS foo
    """
  end

  def user_id
    @user_id ||= current_user.id
  end

end