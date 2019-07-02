require 'rails_helper'

describe SocialShareDisplay do
  let(:work) { create(:work, :with_complete_metadata, representative: create(:asset, :inline_promoted_file))}
  let(:displayer) { SocialShareDisplay.new(work) }
  let(:rendered) { Nokogiri::HTML.fragment( displayer.display )}
  let(:container_div) { rendered.at_css("div.social-media") }


  it "renders social share links" do
    expect(container_div).to be_present

    facebook_link = container_div.at_css("a.facebook")
    expect(facebook_link).to be_present
    expect(facebook_link['href']).to eq "javascript:window.open('https://facebook.com/sharer/sharer.php?u=#{CGI.escape helper.work_url(work)}')"

    twitter_link = container_div.at_css("a.twitter")
    expect(twitter_link).to be_present
    expect(twitter_link['href']).to eq "https://twitter.com/intent/tweet/?url=#{CGI.escape helper.work_url(work)}"

    pinterest_link = container_div.at_css("a.pinterest")
    expect(pinterest_link).to be_present
    pinterest_share_url = pinterest_link["href"]

    expect(pinterest_share_url).to be_present
    pinterest_uri = URI.parse(pinterest_share_url)
    expect(pinterest_uri.host).to eq "pinterest.com"
    expect(pinterest_uri.query).to be_present

    pinterest_params = CGI.parse(pinterest_uri.query)
    expect(pinterest_params["url"]).to eq [helper.work_url(work)]
    expect(pinterest_params["description"]).to eq ["#{work.title} - Science History Institute Digital Collections: #{work.description}"]
    expect(pinterest_params["media"]).to be_present
    expect(Addressable::URI.parse(pinterest_params["media"].first)).not_to be_relative
  end

end
