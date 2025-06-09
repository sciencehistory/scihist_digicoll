# MoreLikeThisGetter.new(work).works
#
# returns an array of zero to ten
# published works that SOLR thinks
# are "like" the given work.
# The array is in order: the first item in
# the one SOLR deemed most "alike".
#
# This calls the SOLR server's more-like-this request handler
# at http://SOME_URL/solr/SOME_CORE/mlt
#
# See also:
# work_indexer.rb for indexing details,
# solr/config/solrconfig.xml for the request handler.
#
# We really do not want to slow down (or worse, break) the work show page
# if SOLR is slow or unreachable, as it often is.
# If anything goes wrong, you'll just get an empty array.
#
# MoreLikeThisGetter.new(work).works
#
class MoreLikeThisGetter
  attr_reader :work

  # These timeouts are short. We want to be conservative,
  # as we don't want to trust our SOLR provider too much
  # and this appears on a part of the website that's usually fast.
  TIMEOUT=1
  OPEN_TIMEOUT=1
  HOW_LONG_TO_CACHE = 7.days

  # @param work [Work] Work
  # @param max_number_of_works: if specified,
  # this limits the number of works returned.
  def initialize(work, max_number_of_works: nil)
    @work = work
    @max_number_of_works = max_number_of_works
  end

  # Returns an array of up to @max_number_of_works
  # published works that SOLR deems similar, in order of similarity
  def works
    return [] if @work&.friendlier_id.nil?
    friendlier_ids.map {|id| works_in_arbitrary_order[id] }.compact
  end

  # Note that we check one last time here using fresh data from the DB
  # that all items returned are published.
  def works_in_arbitrary_order
    @works_in_arbitrary_order ||= Work.where(
      friendlier_id: friendlier_ids,
      published: true).
      includes(:leaf_representative)&.
      index_by(&:friendlier_id) || {}
  end

  # Some justification for the choices SOLR made.
  # Does not result in an additional call to SOLR.
  def json
    more_like_this_doc_set&.map do |doc|
      doc.select do |key, value|
        key == 'text1_tesim' || key.include?('more_like_this')
      end
    end
  end

  # Returns an RSolr::Client configured with our
  # standard blacklight config, except it won't retry failed queries.
  def solr_connection
    # If we don't get a response from SOLR right away,
    # we just want to show the page without the more_like_this content. 
    #
    # Note the existence of Scihist::BlacklightSolrRepository, which we are
    # consciously not using as the solr repo in this method. Its only purpose
    # is to provide two successive retries on failure, which we don't want here.
    @solr_connection ||= begin
      Blacklight::Solr::Repository.new(CatalogController.blacklight_config).connection.tap do |conn|
        conn.connection.params = {
          :timeout => TIMEOUT,
          :open_timeout => OPEN_TIMEOUT
        }
      end
    end
  end

  def more_like_this_doc_set
    @more_like_this_doc_set ||= begin
      solr_connection&.mlt(:params => mlt_params)&.dig("response", "docs") || []
    rescue RSolr::Error::ConnectionRefused,
      RSolr::Error::Http,
      RSolr::Error::InvalidResponse,
      RSolr::Error::Timeout,
      RSolr::Error::InvalidJsonResponse,
      RSolr::Error::InvalidRubyResponse => e
      Rails.logger.error("Encountered #{e.class.name} while trying to fetch more-like-this works for work #{@work.friendlier_id}")
      []
    end
  end

  # Returns the friendlier_ids of the similar works, most similar first.
  # These are cached for a week, to save trips to our flaky solr provider.
  def friendlier_ids
    @friendlier_ids ||= begin
      if read_from_cache.nil?
        more_like_this_doc_set&.map { |d| d['id'] }.tap { |ids| write_to_cache ids }  || []
      else
        read_from_cache
      end
    end
  end

  def read_from_cache
    @read_from_cache ||= Rails.cache.read @work.friendlier_id
  end

  def write_to_cache(array_of_ids_to_cache)
    array_of_ids_to_cache ||= []
    Rails.cache.write(@work.friendlier_id, array_of_ids_to_cache, expires_in: HOW_LONG_TO_CACHE )
  end

  # see https://solr.apache.org/guide/solr/latest/query-guide/morelikethis.html
  def mlt_params
    @mlt_params ||= begin
      parameters = {
        "q"         => "id:#{@work.friendlier_id}",
        "mlt.fl"    => 'more_like_this_keywords_tsimv',
      }
      parameters["rows"] = @max_number_of_works unless @max_number_of_works.nil?
      parameters
    end
  end

  private


  def solr_url
    ScihistDigicoll::Env.lookup!(:solr_url)
  end
end