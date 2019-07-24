# A random selection of recently modified works to display as thumbnails
# on the front page of the site.
# The same selection is shown to all users at the same time.
# The selection is reshuffled every few minutes,
# and is memoized for speed.
# The database is only accessed every @how_often_to_change seconds.

class RecentItems
  @@last_refresh = nil
  @@bag = nil

  def initialize
    @how_many_works_to_show = 6
    @how_often_to_change = 60 * 10 # ten minutes in seconds.
    @how_many_works_in_bag = 50
  end

  def recent_items
    @@bag = nil if time_for_a_new_bag?
    # The randomization function is seeded from @@last_refresh,
    # which is a class instance variable.
    # Hence, the shuffled selection is the same for all users at a given moment.
    fetch_bag.shuffle(random: Random.new(@@last_refresh))[0... @how_many_works_to_show]
  end

  private

  # Don't contact the database more often than @how_often_to_change.
  def time_for_a_new_bag?
    return false if (@@last_refresh.present? && still_fresh?)
    # If you reach this point, it's time to refresh the bag from the database.
    @@last_refresh = Time.now.to_i
    true
  end

  def still_fresh?
    (Time.now.to_i - @@last_refresh) < @how_often_to_change
  end

  def fetch_bag
    @@bag ||= Work.where('published = true').
      order('updated_at').
      limit(@how_many_works_in_bag)
  end
end