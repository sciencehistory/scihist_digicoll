# We display a "child count" in our search results -- for works it's the number of (public) members,
# for collections it's the number of (public) contained items.
#
# We don't want to have to make a separate SQL query per item in results to get this number. (n+1 problem)
#
# The ChildCoundDisplayFetcher is initialized with the friendlier_ids of all items in the currently displaying
# search results, and then will *batch fetch* all child counts in *one fetch* for the entire batch. (Actually one
# fetch for "contains" count and one for "members" count).
#
#     count_fetcher = ChildCountDisplayFetcher.new(array_of_friendlier_ids)
#
#     count_fetcher.member_count_for_friendlier_id(friendlier_id)
#     # => returns integer count of _public_ members of item with that friendlier_id
#
#     count_fetcher.contains_count_for_friendlier_id(friendlier_id)
#     # => returns integer count of _public_ members of item with that friendlier_id
#
# As a convenience, `#display_count_for` takes a *model*, and will return the correct child
# count for display regardless of whether it's a Collection (we want "contains" count), or
# a Work (we want "members" count).
#
#     count_fetcher.display_count_for(collection_or_work_obj)
#
# A ChildCountDisplayFetcher is expected to be created in a Controller, initialized with
# the batch of current displayed search results. And then made available to the view somehow.
class ChildCountDisplayFetcher
  attr_reader :friendlier_ids
  def initialize(friendlier_ids)
    @friendlier_ids = friendlier_ids
  end

  # Convenience method you can pass in a Work or a Collection, and it will return the
  # correct "child count" for search results display -- for a Collection a *contains* count,
  # for a Work, a *members* count.
  def display_count_for(model)
    if model.kind_of?(Collection)
      contains_count_for_friendlier_id(model.friendlier_id)
    else
      member_count_for_friendlier_id(model.friendlier_id)
    end
  end

  # Returns integer (possibly 0) count of _public_ members belonging to item with
  # supplied friendlier_id
  def member_count_for_friendlier_id(friendlier_id)
    unless friendlier_ids.include?(friendlier_id)
      raise ArgumentError.new("This #{self.class.name} can not provide count for '#{friendlier_id}', was initialized for #{friendlier_ids.inspect}")
    end

    member_count_hash.fetch(friendlier_id) { 0 }
  end

  # Returns integer (possibly 0) count of _public_ `contains` items belonging to item with
  # supplied friendlier_id
  def contains_count_for_friendlier_id(friendlier_id)
    unless friendlier_ids.include?(friendlier_id)
      raise ArgumentError.new("This #{self.class.name} can not provide count for '#{friendlier_id}', was initialized for #{friendlier_ids.inspect}")
    end

    contains_count_hash.fetch(friendlier_id) { 0 }
  end

  private

  def member_count_hash
    # Tricky ActiveRecord to do a single SQL query that will fetch member counts for all works in friendlier_ids
    # -- limited to count of members that are 'published'
    #
    #
    # Requires us to have discovered how ActiveRecord aliases self-joined tables mentioned twice in the query,
    # in this case "member_kithe_models"
    #
    # Will return a hash where the key is the friendlier_id, and the value is the integer count of members.
    # Will be nil if no members.
    @member_count_hash ||= Kithe::Model.
                            where(friendlier_id: friendlier_ids).
                            joins(:members).where("members_kithe_models.published" => true).
                            group("friendlier_id").count
  end

  def contains_count_hash
    # Tricky ActiveRecord to do a single SQL query that will fetch 'contains' counts for all works in friendlier_ids
    # # -- limited to count of contained objects that are 'published'
    #
    # Requires us to have discovered how ActiveRecord aliases self-joined tables mentioned twice in the query,
    # in this case "contains_kithe_models"
    #
    # Will return a hash where the key is the friendlier_id, and the value is the integer count of members.
    # Will be nil if no members.
    @contains_count_hash ||= Kithe::Model.
                              where(friendlier_id: friendlier_ids).
                              joins(:contains).where("contains_kithe_models.published" => true).
                              group("friendlier_id").count
  end
end
