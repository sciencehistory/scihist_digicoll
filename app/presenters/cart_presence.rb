# A class for checking if a bunch of Works are in a user's cart, making only one
# DB query. Check is by friendlier_id.
#
# You need to initialize it with all possible friendlier_id values that might be
# checked -- for instance all hits on current page. (Should we instaed just fetch
# ALL ids of items in current user's cart? Would be simpler, maybe dangerous if we start
# putting thousands of things in cart? Unclear, but this works. )
class CartPresence
  attr_reader :friendlier_id_possibilities, :current_user
  def initialize(friendlier_id_possibilities, current_user:)
    @friendlier_id_possibilities =  friendlier_id_possibilities
    @current_user = current_user
  end

  def in_cart?(friendlier_id)
    unless friendlier_id_possibilities.include?(friendlier_id)
      raise ArgumentError("Can only check #in_cart? for an id included in initializer possibilities. `#{friendlier_id}` was not.")
    end

    friendlier_ids_in_cart.include?(friendlier_id)
  end

  private

  # important we are loading this LAZILY, not loaded on demand. So you can instantiate
  # a CartPresnence without paying the cost for the DB query if you never use it.
  #
  # For instance, we might instantiate it on all pages, but only use it for logged-in-users,
  # not logged in users should not have query performance penalty.
  def friendlier_ids_in_cart
    return [] unless current_user

    @friendlier_ids_in_cart ||= Set.new(current_user.works_in_cart.where(friendlier_id: friendlier_id_possibilities).pluck(:friendlier_id))
  end

end
