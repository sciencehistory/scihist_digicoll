require 'rails_helper'

describe "Audio front end", type: :system, js: true do # , solr:true do
  let!(:parent_work) do
    build(:work, rights: "http://creativecommons.org/publicdomain/mark/1.0/")
  end
  let(:audio_file_path) { Rails.root.join("spec/test_support/audio/ice_cubes.mp3")}
  let(:audio_file_sha512) { Digest::SHA512.hexdigest(File.read(audio_file_path)) }
  #let!(:audio_asset) { FactoryBot.create(:asset, file: File.open(audio_file_path)) }

  let!(:audio_assets) {
    (1..3).to_a.map do |i|
      create(:asset_with_faked_file, :mp3,
        title: "Track #{i}",
        position: i - 1,
        parent: parent_work,
        faked_derivatives: [
            build(:faked_derivative, key: 'small_mp3', uploaded_file: build(:stored_uploaded_file, content_type: "audio/mpeg")),
            build(:faked_derivative, key: 'webm',      uploaded_file: build(:stored_uploaded_file, content_type: "audio/webm"))
        ]
      )
    end
  }
  let!(:regular_assets) {
    (4..6).to_a.map do |i|
      create(:asset_with_faked_file,
        title: "Regular file #{i}",
        faked_derivatives: [],
        position: i - 1,
        parent: parent_work
      )
    end
  }

  before do
    parent_work.representative = regular_assets[0]
    parent_work.save!
  end

  context "When you visit a work with audio assets" do
    it "shows the page without error" do
      visit work_path(audio_assets.first.parent.friendlier_id)
      within(".show-page-audio-playlist-wrapper") do
        expect(page).to have_css(".current-track-label", :text => "Track 1")
        audio_element = page.find('.show-page-audio-playlist-wrapper audio')
        track_listings = page.find_all('.track-listing')
        expect(track_listings.map {|x| x['data-title'] }).to contain_exactly("Track 1", "Track 2", "Track 3")
        expect(track_listings.map {|x| x['data-member-id'] }).to eq audio_assets.map {|x| x.id}
        download_links = page.find_all('.dropdown-item:not(.dropdown-header)', :visible => false).map { |x| x['href'] }
        (0..2).to_a.map do |i|
          expect(download_links.any? { |x| x.include? "#{audio_assets[i].friendlier_id}/small_mp3" }).to be true
        end
        # Original file + two derivatives:
        expect(download_links.count).to eq audio_assets.count * ( 1 + 2)
        # The two derivatives are served by the downloads controller:
        expect(download_links.select{ |x| x.include? 'downloads'}.count).to eq audio_assets.count * 2
      end

      other_thumbs = page.find_all('.member-image-presentation')
      expect(other_thumbs.count). to eq regular_assets.count
    end
  end
end
