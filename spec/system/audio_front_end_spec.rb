require 'rails_helper'

describe "Audio front end", type: :system, js: true do
  let!(:parent_work) do
    build(:public_work, rights: "http://creativecommons.org/publicdomain/mark/1.0/")
  end
  let(:audio_file_path) { Rails.root.join("spec/test_support/audio/ice_cubes.mp3")}
  let(:audio_file_sha512) { Digest::SHA512.hexdigest(File.read(audio_file_path)) }


  let(:combined_audio_file_path) {
    Rails.root.join("spec/test_support/audio/double_ice_cubes.mp3")
  }

  let!(:audio_assets) {
    (1..4).to_a.map do |i|
      create(:asset_with_faked_file, :mp3,
        title: "Track #{i}",
        position: i - 1,
        parent: parent_work,

        # All of these are published except for the second one.
        published: i != 2
      )
    end
  }

  let!(:published_audio_assets) {
    audio_assets.select {|a| a.published }
  }

  let!(:regular_assets) {
    (5..8).to_a.map do |i|
      create(:asset_with_faked_file,
        title: "Regular file #{i}",
        faked_derivatives: [],
        position: i - 1,

        #5, #7 and #8 are published, but not #6:
        published: i != 6,

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

      # Because there is no combined audio derivative,
      # we can't show the audio scrubber:
      expect(page).not_to have_selector('audio')

      click_on "Downloads"

      within("*[data-role='audio-playlist-wrapper']") do
        expect(page).not_to have_css('.now-playing-container')
        expect(page).to have_css("*[data-role='no-audio-alert']")
        track_listings = page.find_all('.track-listing')
        # The user is not logged in, and Track 2 is not published yet.
        # Thus, Track 2 should not be shown.
        expect(track_listings.map {|x| x['data-title'] }).to contain_exactly("Track 1", "Track 3", "Track 4")
        expect(track_listings.map {|x| x['data-member-id'] }).to eq published_audio_assets.map {|x| x.id}

        download_links = page.find_all('.track-listing .dropdown-item', :visible => false).map { |x| x['href'] }

        # Original file + rights link:
        expect(download_links.count).to eq published_audio_assets.count * 2
        # original is served by the downloads controller:
        expect(download_links.select{ |x| x.include? 'downloads'}.count).to eq published_audio_assets.count
      end

      non_audio = page.find_all('.other-files .show-member-list-item')

      # Don't show the unpublished non-audio asset (# 6) to the not-logged-in user.
      expect(non_audio.count). to eq regular_assets.count {|a| a.published }

      # No user is logged in, so there should not be any "Private" badges.
      expect(page).not_to have_css('.badge-warning[title=Private]')


      # Add an oral_history_content sidecar object
      # and populate it.
      # Ideally this would be a separate #it block.
      # This ought to save a bit of testing time, though.
      id_list = parent_work.
        members.order(:position).
        select{|x| x.content_type == 'audio/mpeg' && x.published? }.
        map {|x| x.id}

      parent_work.oral_history_content!.set_combined_audio_mp3!(File.open(combined_audio_file_path))
      parent_work.oral_history_content.combined_audio_component_metadata = {"start_times"=>[
        [id_list[0], 0],
        [id_list[1], 0.5],
        [id_list[2], 1]
      ]}
      visit work_path(parent_work.friendlier_id)

      # Oh, wait. The item does not have an
      # up to date fingerprint. No audio tag should be shown.
      expect(page).to have_css("*[data-role='no-audio-alert']")
      expect(page).not_to have_selector('audio')

      # OK, let's set the combined audio fingerprint.
      fp = CombinedAudioDerivativeCreator.
        new(parent_work).fingerprint
      parent_work.oral_history_content.combined_audio_fingerprint = fp
      parent_work.oral_history_content.save!
      visit work_path(parent_work.friendlier_id)

      # No we should see audio.
      expect(page).not_to have_css("*[data-role='no-audio-alert']")
      expect(page).to have_selector('audio')
      expect(page).to have_selector(".track-listing[data-ohms-timestamp-s=\"0\"]" , visible: false)
      expect(page).to have_selector(".track-listing[data-ohms-timestamp-s=\"0.5\"]" , visible: false)
      expect(page).to have_selector(".track-listing[data-ohms-timestamp-s=\"1\"]" , visible: false)

      click_on "Downloads"
      scrubber_times = []
      scrubber_times << evaluate_script("document.getElementsByTagName('audio')[0].currentTime")
      [1, 3, 4].each do |track_number|
        click_on "Track #{track_number}", match: :first
        scrubber_times << evaluate_script("document.getElementsByTagName('audio')[0].currentTime")
      end
      # This doesn't need to be super precise.
      # We just want a general reassurance
      # that the playhead is moving
      # when you click the links.
      expect(scrubber_times.map {|x| (x*2).round }).to contain_exactly(0,0,1,2)

      # You should be able to download the combined audio derivs:
      expect(page).to have_content("All 3 segments as a single file")
      expect(page).to have_content("Download mp3")

    end
  end

  describe "Public audio work show page (shown to a logged-in user)", :logged_in_user, type: :system, js: true do

    let!(:parent_work) do
      build(:work, rights: "http://creativecommons.org/publicdomain/mark/1.0/")
    end
    let(:audio_file_path) { Rails.root.join("spec/test_support/audio/ice_cubes.mp3")}
    let(:audio_file_sha512) { Digest::SHA512.hexdigest(File.read(audio_file_path)) }

    let!(:audio_assets) {
      (1..4).to_a.map do |i|
        create(:asset_with_faked_file, :mp3,
          title: "Track #{i}",
          position: i - 1,
          parent: parent_work,

          # All of these are published except for the second one.
          published: i != 2
        )
      end
    }

    let!(:published_audio_assets) {
      audio_assets.select {|a| a.published }
    }

    let!(:regular_assets) {
      (5..8).to_a.map do |i|
        create(:asset_with_faked_file,
          title: "Regular file #{i}",
          faked_derivatives: [],
          position: i - 1,

          #5, #7 and #8 are published, but not #6:
          published: i != 6,

          parent: parent_work
        )
      end
    }

    before do
      parent_work.representative = regular_assets[0]
      parent_work.save!
    end

    describe "Logged in user" do
      it "shows the edit button, and all child items, including unpublished ones." do
        visit work_path(audio_assets.first.parent.friendlier_id)

        click_on "Downloads"

        # Audio tracks:
        within("*[data-role='audio-playlist-wrapper']") do
          audio_assets.each do |audio_asset|
            track_listing_css = ".track-listing[data-title=\"#{audio_asset.title}\"]"
            # All tracks are displayed, including the unpublished ones:
            expect(page).to have_css(track_listing_css)
            if audio_asset.published?
              expect(page).not_to have_css("#{track_listing_css} .badge-warning[title=Private]")
            else
              expect(page).to have_css("#{track_listing_css} .badge-warning[title=Private]")
            end
          end
        end


        # Regular assets:

        # All files are listed, including the unpublished ones:

        other_files = page.find_all('.other-files .show-member-list-item')
        expect(other_files.count).to eq regular_assets.count

        # Thumbs corresponding to an unpublished asset are labeled:
        other_files.each do |file_listing|
          friendlier_id =  file_listing['data-member-id']
          asset = regular_assets.select{ |ra| ra.friendlier_id == friendlier_id }.first
          expect(asset).not_to eq nil
          if asset.published?
            expect(file_listing).to have_no_css('.badge-warning[title=Private]')
          else
            expect(file_listing).to have_css('.badge-warning[title=Private]')
          end
        end
      end
    end
  end
end
