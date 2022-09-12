# MoreLikeThisGetter.new(work).works
#
# returns an array of zero to ten
# published works that SOLR thinks
# are "like" the given work.
#
# This calls the SOLR server's more-like-this request handler
# at http://SOME_URL/solr/SOME_CORE/mlt
# to request a list of works that are deemed similar.
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

  # @param work [Work] Work
  def initialize(work, max_number_of_works: nil)
    @work = work
    @max_number_of_works = max_number_of_works
  end

  # Returns an array of up to @max_number_of_works
  # published works that SOLR deems similar.
  def works
    friendlier_ids.map {|id| works_in_arbitrary_order[id] }.compact
  end

  def works_in_arbitrary_order
    @works_in_arbitrary_order ||= Work.where(
      friendlier_id: friendlier_ids,
      published: true)&.
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

  def solr_connection
    RSolr.connect(
      :url          => solr_url,
      :timeout      => TIMEOUT,
      :open_timeout => OPEN_TIMEOUT
    )
  end

  def more_like_this_doc_set
    @more_like_this_doc_set ||= begin
      solr_connection&.get('mlt', :params => mlt_params)&.
       dig("response", "docs") || []
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

  private

  # Returns the friendlier_ids of the similar works, most similar first.
  # Note: SOLR appears to return ten items by default,
  # and we have yet to figure out if it's possible to ask the
  # more-like-this request handler to return fewer than the default.
  # Simply adding mlt.count to the query does not work.
  def friendlier_ids
    @friendlier_ids ||= begin
      truncated_doc_set = if @max_number_of_works.nil?
        more_like_this_doc_set
      else
        more_like_this_doc_set[0..@max_number_of_works-1]
      end
      truncated_doc_set&.map { |d| d['id'] }
    end
  end


  def mlt_params
    @mlt_params ||= {
      "q"         => "id:#{@work.friendlier_id}",
      "mlt.fl"    => 'more_like_this_keywords_tsimv'
    }
  end

  def solr_url
    ScihistDigicoll::Env.lookup!(:solr_url)
  end


end