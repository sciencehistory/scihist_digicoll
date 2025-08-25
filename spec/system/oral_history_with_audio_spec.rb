require 'rails_helper'

# Testing the view that has an audio player, sometimes with OHMS.
describe "Oral history with audio display", type: :system, js: true do
  let(:portrait) { create(:asset_with_faked_file, role: "portrait")}

  let!(:parent_work) do
    create(:oral_history_work, :published, :ohms_xml, members: [portrait])
  end

  let(:audio_file_path) { Rails.root.join("spec/test_support/audio/5-seconds-of-silence.mp3")}
  let(:audio_file_sha512) { Digest::SHA512.hexdigest(File.read(audio_file_path)) }


  let(:combined_audio_file_path) {
    Rails.root.join("spec/test_support/audio/5-seconds-of-silence.mp3")
  }

  let!(:audio_assets) {
    (1..4).to_a.map do |i|
      create(:asset_with_faked_file, :mp3,
        title: "Track #{i}",
        position: i - 1,
        parent: parent_work,

        # All of these are published except for the second one.
        published: i != 2,
        faked_derivatives: {},
      )
    end
  }

  let!(:published_audio_assets) {
    audio_assets.select {|a| a.published }
  }

  let!(:image_assets) {
    (5..8).to_a.map do |i|
      create(:asset_with_faked_file,
        title: "Regular file #{i}",
        faked_derivatives: {},
        position: i - 1,

        #5, #7 and #8 are published, but not #6:
        published: i != 6,

        parent: parent_work
      )
    end
  }

  let(:pdf_asset) do
    create(:asset_with_faked_file, :pdf,
      faked_derivatives: {},
      parent: parent_work
    )
  end


  before do
    parent_work.representative = pdf_asset
    parent_work.save!
  end

  context "When you visit a work with audio assets" do
    it "shows audio assets appropriately" do
      visit work_path(audio_assets.first.parent.friendlier_id)

      # Our tabs do not meet color contrast rules, we're ignoring for now.
      expect(page).to be_axe_clean.excluding(".ohms-nav-tabs")


      # Because there is no combined audio derivative,
      # we can't show the audio scrubber:
      expect(page).not_to have_selector('audio')


      click_on "Description"

      # portrait
      expect(page).to have_selector(".oh-portrait img[src='#{portrait.file_url(:thumb_standard)}']")

      # Biographical metadata, just test a sampling
      expect(page).to have_selector("h2", text: "Interviewee biographical information")
      expect(page).to have_text(FormatSimpleDate.new(parent_work.oral_history_content.interviewee_biographies.first.birth.date).display)
      expect(page).to have_text(FormatSimpleDate.new(parent_work.oral_history_content.interviewee_biographies.first.birth.city).display)
      expect(page).to have_text(FormatSimpleDate.new(parent_work.oral_history_content.interviewee_biographies.first.death.date).display)
      expect(page).to have_text(FormatSimpleDate.new(parent_work.oral_history_content.interviewee_biographies.first.death.city).display)

      expect(page).to have_text parent_work.oral_history_content.interviewee_biographies.first.job.first.institution
      expect(page).to have_text parent_work.oral_history_content.interviewee_biographies.first.job.first.role
      expect(page).to have_text parent_work.oral_history_content.interviewee_biographies.first.job.first.start.slice(0..3)

      expect(page).to have_text parent_work.oral_history_content.interviewee_biographies.first.school.first.institution
      expect(page).to have_text parent_work.oral_history_content.interviewee_biographies.first.school.first.date.slice(0..3)
      expect(page).to have_text parent_work.oral_history_content.interviewee_biographies.first.school.first.degree
      expect(page).to have_text parent_work.oral_history_content.interviewee_biographies.first.school.first.discipline

      expect(page).to have_text parent_work.oral_history_content.interviewee_biographies.first.honor.first.start_date.slice(0..4)
      expect(page).to have_text parent_work.oral_history_content.interviewee_biographies.first.honor.first.honor


      click_on "Downloads"

      # In oh_audio_work_show_decorator.rb we specify that only PDFs should be linked.

      #PDF has a link:
      linked_pdf_transcripts = find_all('.show-member-file-list-item a').select { |x| x.text == pdf_asset.title }
      expect(linked_pdf_transcripts.count).to eq 1
      #linked_pdf_transcripts[0]

      expect(linked_pdf_transcripts[0]['data-analytics-category']).to eq "Work"
      expect(linked_pdf_transcripts[0]['data-analytics-action']  ).to eq "view_oral_history_transcript_pdf"
      expect(linked_pdf_transcripts[0]['data-analytics-label']   ).to eq parent_work.friendlier_id
      # 3 JPEGS: not linked


      expect(find_all('.show-member-file-list-item a').select { |x| x.text == image_assets[0].title }.count).to eq 0
      expect(find_all('.show-member-file-list-item a').select { |x| x.text == image_assets[1].title }.count).to eq 0
      expect(find_all('.show-member-file-list-item a').select { |x| x.text == image_assets[2].title }.count).to eq 0

      within("*[data-role='audio-playlist-wrapper']") do
        within('.now-playing-container') do
          expect(page).to have_css("*[data-role='no-audio-alert']")
        end

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

      non_audio = page.find_all('.other-files .show-member-file-list-item')

      # Don't show the unpublished non-audio asset (# 6) to the not-logged-in user.
      # (The + 1 accounts for the PDF, which is not an image but is also not audio.)
      expect(non_audio.count). to eq image_assets.count {|a| a.published } + 1


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

      parent_work.oral_history_content!.set_combined_audio_m4a!(File.open(combined_audio_file_path))
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

      # Now we should see audio, although raw html <audio> is hidden by video.js player
      expect(page).not_to have_css("*[data-role='no-audio-alert']")
      expect(page).to have_selector('.video-js')

      click_on "Downloads"


      # click on icons to play
      expect(page).to have_selector(".track-listing div.title a.play-link[data-ohms-timestamp-s=\"0\"]" )
      expect(page).to have_selector(".track-listing div.title a.play-link[data-ohms-timestamp-s=\"0.5\"]")
      expect(page).to have_selector(".track-listing div.title a.play-link[data-ohms-timestamp-s=\"1\"]")

      # click on titles to play
      expect(page).to have_selector(".track-listing div.icon a.play-link[data-ohms-timestamp-s=\"0\"]")
      expect(page).to have_selector(".track-listing div.icon a.play-link[data-ohms-timestamp-s=\"0.5\"]")
      expect(page).to have_selector(".track-listing div.icon a.play-link[data-ohms-timestamp-s=\"1\"]")

      current_time_js = "document.getElementsByTagName('audio')[0].currentTime"
      scrubber_times = []
      scrubber_times << evaluate_script(current_time_js)
      [1, 3, 4].each do |track_number|
        page.find('a.play-link', text: "Track #{track_number}").click
        click_on "Track #{track_number}", match: :first
        scrubber_times << evaluate_script(current_time_js)
      end
      # This doesn't need to be super precise.
      # We just want a general reassurance
      # that the playhead is moving
      # when you click the links.
      expect(scrubber_times.map {|x| (x*2).round }).to contain_exactly(0,0,1,2)

      # Make sure we're sending a GA action when the user clicks on a track
      page.find_all('a.play-link').each do |link|
          expect(link['data-analytics-category']).to eq "Work"
          expect(link['data-analytics-action']  ).to eq "play_oral_history_audio_segment"
          expect(link['data-analytics-label']   ).to eq parent_work.friendlier_id
      end

      # You should be able to download the combined audio derivs:
      expect(page).to have_content("Complete Interview Audio File")
      expect(page).to have_content("3 Separate Interview Segments")
      expect(page).to have_content(/\d\.\d KB/)
    end
  end

  context "with combined audio and OHMS" do
    before do
      parent_work.oral_history_content.combined_audio_m4a = create(:stored_uploaded_file,
        file: File.open((Rails.root + "spec/test_support/audio/10-minutes-of-silence.m4a")),
        content_type: "audio/mpeg")
      parent_work.oral_history_content.combined_audio_fingerprint = CombinedAudioDerivativeCreator.new(parent_work).fingerprint
      parent_work.oral_history_content.save!
    end

    it "can use 'jump to text' feature" do
      visit work_path(parent_work.friendlier_id)

      # to get player to 5:05, we're just going to hackily execute JS
      page.execute_script(%q{document.querySelector("audio[data-role='ohms-audio-elem']").currentTime = 305;})

      click_button "Jump to text"
      expect(page).to have_text("00:05:00")
      # since that's at the top of visible transcript, earlier minute should be scrolled off
      expect(page).not_to have_text("00:04:00")
    end

    it "can link to timecode on transcript" do
      visit work_path(parent_work.friendlier_id, anchor: "t=306")

      # jump to 05:00 at top of page, on transcript tab

      expect(page).to have_selector("#ohTranscript.tab-pane.active")
      expect(page).to have_text("00:05:00")
      expect(page).not_to have_text("00:04:00")
    end

    it "has popup with URL with timecode" do
      # not sure why we need to specify capybara port manually to see what we expect
      expected_displayed_url = work_url(parent_work.friendlier_id, port: Capybara.current_session.server.port)

      visit work_path(parent_work.friendlier_id)

      click_on "Share link"
      expect(page).to have_text("Share link to this page")

      within(".modal-content") do
        expect(page).to have_field(readonly: true, with: expected_displayed_url)
        check "Start audio at 00:00:00"
        expect(page).to have_field(readonly: true, with: "#{expected_displayed_url}#t=0")
      end
    end

    it "can use 'jump to text' feature for ToC tab" do
      visit work_path(parent_work.friendlier_id)

      click_on "Table of Contents"

       # to get player to 5:05, we're just going to hackily execute JS
      page.execute_script(%q{document.querySelector("audio[data-role='ohms-audio-elem']").currentTime = 305;})

      click_button "Jump to text"
      expect(page).to have_text("00:04:16") # nearest ToC section
      expect(page).to have_text("Many family members are scientists.") # open synopsis for 04:16

      # I guess capybara can see this even though it is scrolled under navabar.
      #expect(page).not_to have_text("00:00:00") # earlier ToC section
    end

    it "can jump to specific ToC segment" do
      visit work_path(parent_work.friendlier_id, anchor: "t=305&tab=ohToc")

      expect(page).to have_selector("#ohToc.tab-pane.active")
      expect(page).to have_text("00:04:16") # nearest ToC section
      expect(page).to have_text("Many family members are scientists.") # open synopsis for 04:16
    end
  end

  describe "when you are logged-in staff", :logged_in_user, type: :system, js: true do

    let!(:parent_work) do
      build(:oral_history_work, rights: "http://creativecommons.org/publicdomain/mark/1.0/")
    end
    let(:audio_file_path) { Rails.root.join("spec/test_support/audio/5-seconds-of-silence.mp3")}
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

    let!(:image_assets) {
      (5..8).to_a.map do |i|
        create(:asset_with_faked_file,
          title: "Regular file #{i}",
          faked_derivatives: {},
          position: i - 1,

          #5, #7 and #8 are published, but not #6:
          published: i != 6,

          parent: parent_work
        )
      end
    }

    before do
      parent_work.representative = image_assets[0]
      parent_work.save!
    end

    it "shows the edit button, and all child items, including unpublished ones." do
      visit work_path(audio_assets.first.parent.friendlier_id)

      find(".nav a", text: "Downloads").click

      # Audio tracks:
      within("*[data-role='audio-playlist-wrapper']") do
        audio_assets.each do |audio_asset|
          track_listing_css = ".track-listing[data-title=\"#{audio_asset.title}\"]"
          # All tracks are displayed, including the unpublished ones:
          expect(page).to have_css(track_listing_css)
          if audio_asset.published?
            expect(page).not_to have_css("#{track_listing_css} .badge[title=Private]")
          else
            expect(page).to have_css("#{track_listing_css} .badge[title=Private]")
          end
        end
      end

      # Regular assets:
      # All files are listed, including the unpublished ones:

      other_files = page.find_all('.other-files .show-member-file-list-item')
      #  All files = audio files + image files + 1 PDF file.
      expect(other_files.count).to eq image_assets.count + 1

      # Thumbs corresponding to an unpublished asset are labeled:
      other_files.each do |file_listing|
        friendlier_id =  file_listing['data-member-id']
        asset = image_assets.select{ |ra| ra.friendlier_id == friendlier_id }.first

        # If the asset doesn't match any of the images, assume it's the PDF transcript:
        asset = asset || pdf_asset

        expect(asset).not_to eq nil
        if asset.published?
          expect(file_listing).to have_no_css('.badge[title=Private]')
        else
          expect(file_listing).to have_css('.badge[title=Private]')
        end
      end
    end
  end

  describe "With OHMS synchronized transcript and ToC" do
    let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/legacy/duarte_OH0344.xml" }
    let(:interviewer_profile) { InterviewerProfile.create(name: "Smith, John", profile: "This has some <i>html</i>")}

    let(:parent_work) {
      create(:oral_history_work, :published, rights: "http://creativecommons.org/publicdomain/mark/1.0/").tap do |work|
        work.oral_history_content!.update(ohms_xml_text: File.read(ohms_xml_path), interviewer_profiles: [interviewer_profile])
      end
    }

    it "can display, and search, without errors" do
      visit work_path(audio_assets.first.parent.friendlier_id)

      within(".ohms-nav-tabs") do
        expect(page).to have_content("Description")
        expect(page).to have_content("Table of Contents")
        expect(page).to have_content("Transcript")
        expect(page).to have_content("Downloads")
      end

      within("*[data-ohms-search-form]") do
        page.find("*[data-ohms-input-query]").fill_in with: "Duarte"
        click_on "Search"
      end

      # ToC tab should be selected as it is first tab with results from search
      expect(page).to have_selector("#ohTocTab[aria-selected='true']")

      begin
        expect(page).to have_selector(".ohms-result-navigation", text: "TABLE OF CONTENTS — 1 / 7", wait: 0.05)
      rescue RSpec::Expectations::ExpectationNotMetError
        within("*[data-ohms-search-form]") { click_on "Search" }
        expect(page).to have_selector(".ohms-result-navigation", text: "TABLE OF CONTENTS — 1 / 7")
      end

      expect(page).to have_selector("*[data-ohms-hitcount='index']", text: "7")
      expect(page).to have_selector("*[data-ohms-hitcount='transcript']", text: "43")
      click_on "Description"
      # We expect the Description tab to be moved to, but for some reason sometimes
      # the click doesn't work to change tabs... bootstrap tab wasn't ready for it for some reason?...
      # Don't know if it's a bug in our stuff or bootstrap or neither, but does not seem
      # to affect humans (we hope), we just have to work around it in tests for now, finding
      # no alternative.
      #
      # Simple as: If it didn't work the first time, we try clicking again.
      begin
        # shorter wait time, if it didn't happen, it's not going to. 50ms
        find("#ohDescriptionTab[aria-selected='true']", wait: 0.05)
      rescue Capybara::ElementNotFound
        click_on "Description"
        find("#ohDescriptionTab[aria-selected='true']")
      end

      expect(page).to have_selector("h2", text: "About the Interviewer", wait: 10)
      expect(page).to have_text("This has some html")
    end

    describe "table of contents segment direct link" do
      let(:segment) { parent_work.oral_history_content.ohms_xml.index_points.second }
      let(:segment_direct_url) do
        # don't know why we need to specify capybara port to get the port that is actually
        # being used and succesfully displayed in app.
        work_url(parent_work.friendlier_id, anchor: "t=#{segment.timestamp}&tab=ohToc",
          port: Capybara.current_session.server.port)
      end

      it "is visible and copyable" do
        # The giant fixed navbar and small window size makes it very hard to get
        # this test to pass in capybara, even though as a user it's FAIRLY easy to
        # scroll correctly. But let's just make a bigger window for this test.
        page.current_window.resize_to(820, 600)

        visit work_path(parent_work.friendlier_id)

        click_on "Table of Contents"
        click_on segment.title

        within(".bottom") do
          click_on "Share link"
        end

        expect(page).to have_field(readonly: true, with: segment_direct_url)

        copy_to_clipboard = page.find("*[data-trigger='linkClipboardCopy']")
        page.scroll_to(copy_to_clipboard, align: :bottom)

        begin
          copy_to_clipboard.click
        rescue Selenium::WebDriver::Error::ElementClickInterceptedError
          # try again, things may still have been moving, gah.
          page.scroll_to(copy_to_clipboard, align: :bottom)
          copy_to_clipboard.click
        end

        expect(page).to have_content("Copied to clipboard")
      end
    end
  end
end
