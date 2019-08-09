require 'rails_helper'

describe "Audio front end", type: :system, js: true do # , solr:true do

  let(:parent_work) do
    build(:work, rights: "http://creativecommons.org/publicdomain/mark/1.0/")
  end

  let(:assets) {
    (1..3).to_a.map do |i|
      create(:asset_with_faked_file, :mp3,
        title: "Track #{i}",
        position: i - 1,
        parent: parent_work
      )
    end
  }

  scenario "Non-staff user can see the playlist but not the regular item listings" do
    visit work_path(assets.first.parent.friendlier_id)
    within(".show-page-audio-playlist-wrapper") do
      # TODO:
      # application.js can't load member_sortable, tab_selection_in_anchor,
      # or simple_uppy_file_input in the test context apparently.
      # This in turn causes the JS on this page to fail.
      # expect(page).to have_css(".current-track-label", :text => "Track 1")
      audio_element = page.find('.show-page-audio-playlist-wrapper audio')
      track_listings = page.find_all('.track-listing')
      expect(track_listings.map {|x| x['data-title'] }).to contain_exactly("Track 1", "Track 2", "Track 3")
      expect(track_listings.map {|x| x['data-member-id'] }).to eq assets.map {|x| x.id}
      download_links = page.find_all('.dropdown-item:not(.dropdown-header)', :visible => false).map { |x| x['href'] }
      (0..2).to_a.map do |i|
        expect(download_links.any? { |x| x.include? "#{assets[i].friendlier_id}/small_mp3" }).to be true
      end
      expect(download_links.count).to eq 9
      expect(download_links.select{ |x| x.include? 'downloads'}.count).to eq 6
     end
  end
end
