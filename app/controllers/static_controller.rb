class StaticController < ApplicationController
  def about
  end

  def contact
  end

  def faq
  end

  def policy
  end

  def api_docs
  end

  def oh_legacy_url_not_found
    Rails.logger.warn("Unknown legacy oral histories url: #{request.url}; referer: #{request.referer} ")

    @original_url = request.url
    @original_referer = request.referer

    subject = ERB::Util.url_encode('Missing oral history URL on digital collections')
    body = ERB::Util.url_encode("url: #{@original_url}\nreferrer: #{@original_referrer}")
    @report_mailto = "mailto:#{ScihistDigicoll::Env.lookup!(:oral_history_email_address)}?subject=#{subject}&body=#{body}"

    render status: 404
  end

  # our oh_legacy action can be displayed via the old oh.sciencehistory.org host, make
  # sure rendered links are to our actual preferred host.
  def default_url_options
    { host: ScihistDigicoll::Env.lookup!(:app_url_base) }
  end
end
