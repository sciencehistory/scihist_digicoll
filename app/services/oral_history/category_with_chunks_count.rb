module OralHistory
  # produces counts of different categories of oral histories, using caching. OH's must
  # have chunks to be included.
  #
  # Mostly for use with AI conversations.
  #
  # TODO:  replace with DRY scopes, see #3253.
  #
  # @example  CategoryWithChunksCount.new(category: :immediate_only).fetch_count
  class CategoryWithChunksCount
    VALID_CATEGORIES = [:immediate_ohms_only, :immediate_only, :immediate_or_automatic, :all]

    attr_reader :category, :cache_expires_in

    # @param category [Symbol] [:immediate_ohms_only, :immediate_only, :immediate_or_automatic, :all]
    #
    # @param cache_expires_in [Integer] seconds, defaults to 12.hours, set to false to disable caching,
    #   which you don't want to do really.
    def initialize(category: category, cache_expires_in: 12.hours)
      unless category.in?(VALID_CATEGORIES)
        raise ArgumentError, "category #{category} must be in #{VALID_CATEGORIES}"
      end

      @category = category
      @cache_expires_in = cache_expires_in
    end

    def fetch_count
      if cache_expires_in
        Rails.cache.fetch(cache_key, expires_in: cache_expires_in) do
          scope_for_category.count
        end
      else
        scope_for_category.count
      end
    end

    private

    def cache_key
      "oh_access_limit_count/#{category.to_s}"
    end

    def valid_chunks_scope
      @valid_chunks_scope ||=
        OralHistoryContent.joins(:work).where(work: { published: true }).where.associated(:oral_history_chunks).distinct
    end

    def scope_for_category
      case category
      when :immediate_ohms_only
        valid_chunks_scope.with_ohms
      when :immediate_only
        valid_chunks_scope.availability_direct
      when :immediate_or_automatic
        valid_chunks_scope.direct_or_automatic
      when :all
        valid_chunks_scope.all_except_fully_embargoed
      else
        raise TypeError, "how did we get here, unrecognized category #{category}"
      end
    end
  end
end
