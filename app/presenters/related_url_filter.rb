# Our Works and Collections have a related_url property that is an array of strings.
#
# These can include arbitrary URLs, which are just displayed as a list of actual URLs as hyperlinks.
#
# But for legacy reasons we sometimes cram some "special"
# stuff in there, that needs to be recognized and displayed specially, and not displayed as
# generic related URL.
#
# For instance, links to catalog, and links to related records.
#
# This class filters those 'special' ones out of related URLs, and also provides methods
# to access the 'special' stuff filtered out.
#
# In the future, we may refactor our metadata to actually identify these clearly, instead
# of having to recognize certain URL patterns.
class RelatedUrlFilter
  OPAC_PREFIX_RE = /\Ahttps?:\/\/othmerlib\.(chemheritage|sciencehistory)\.org\/record=/
  RELATED_WORK_PREFIX_RE = %r{\A\s*https?://digital\.sciencehistory\.org/(works/|concern/generic_works/)}

  attr_reader :input_related_urls, :opac_urls, :filtered_related_urls, :related_work_urls

  def initialize(related_urls)
    @input_related_urls = related_urls || []
    filter!
  end

  # Take the ID out of the URL for any work URL referencing our app. It's a friendlier_id
  # cause that's what we use in our URLs.
  def related_work_friendlier_ids
    @related_work_friendlier_ids ||= related_work_urls.collect {|u| u.sub(RELATED_WORK_PREFIX_RE, '') }
  end

  def opac_ids
    @opac_ids ||= opac_urls.collect {|u| u.sub(OPAC_PREFIX_RE, '') }
  end

  # Just a convenience class method to turn a bib_id into a link to the OPAC.
  def self.opac_url(bib_id)
    "https://othmerlib.sciencehistory.org/record=#{CGI.escape bib_id}"
  end

  private

  def filter!
    @filtered_related_urls, @opac_urls, @related_work_urls = [], [], []

    @input_related_urls.each do |url|
      if OPAC_PREFIX_RE.match(url)
        @opac_urls << url
      elsif RELATED_WORK_PREFIX_RE.match(url)
        @related_work_urls << url
      else
        @filtered_related_urls << url
      end
    end
  end
end
