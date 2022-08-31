# Makes an extra call to the SOLR server's more-like-this request handler
# at http://SOME_URL/solr/SOME_CORE/mlt
# to request a list of works that are deemed similar.
# See the work_indexer.rb for indexing details.
#
#
# This code is invoked on the work show page,
# which gets all its other information
# from the database and is generally very fast.
# An important goal for this helper class is that it
# not slow down (or worse, break) the work show page
# if SOLR is slow or unreachable.
#
# MoreLikeThisGetter.new(work).works
#
class MoreLikeThisGetter
  attr_reader :work
  TIMEOUT=1
  OPEN_TIMEOUT=1

  # @param work [Work] Work
  def initialize(work) 
    @work = work
  end

  # Note: it appears that the mlt.count variable is ignored.
  # mlt.qf causes a failure.
  def mlt_params
    @mlt_params ||= {
      "q"         => "id:#{@work.friendlier_id}",
      "mlt.fl"    => 'more_like_this_keywords_tsimv,more_like_this_fulltext_tsimv'
    }
  end

  # Returns a RSolr::Response::PaginatedDocSet
  def more_like_this_doc_set
    @more_like_this_doc_set ||= begin
      solr = RSolr.connect(:url => ScihistDigicoll::Env.lookup!(:solr_url), :timeout => TIMEOUT, :open_timeout => OPEN_TIMEOUT)
      solr.get('mlt', :params => mlt_params)&.
        dig("response", "docs") || []
    rescue
      []
    end
  end

  # Returns an array of up to 10 published works that SOLR deems similar.
  def works
    ids = more_like_this_doc_set&.map { |d| d['id'] }
    works_in_arbitrary_order = Work.where(friendlier_id: ids, published: true).index_by(&:friendlier_id)
    ids.map {|id| works_in_arbitrary_order[id] }.compact
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
end