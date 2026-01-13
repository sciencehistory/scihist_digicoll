FactoryBot.define do
  sequence(:oh_filename, 0) { |n| "smith_j_0001_1_#{n}" }

  factory :work, aliases: [:private_work], class: Work do
    title { 'Test title' }
    published { false }
    external_id do [
        Work::ExternalId.new({"value"=>"Past Perfect ID 1",   "category"=>"object"}),
        Work::ExternalId.new({"value"=>"Sierra Bib Number 1", "category"=>"bib"   }),
        Work::ExternalId.new({"value"=>"Sierra Bib Number 2", "category"=>"bib"   }),
        Work::ExternalId.new({"value"=>"Accession Number 1",  "category"=>"accn"  })
      ]
    end

    # Automatically set a representative if needed and possible
    after(:build) do |work|
      if work.representative.nil? && work.members.loaded?
        work.representative = work.members.to_a.find {|w| w.published? }
      end
    end

    trait :published do
      published { true }
      published_at { Time.now - 86400}
      members {  [ build(:asset_with_faked_file, published: true) ] } # published works need a representative now
      department { "Library" }
      rights { "http://creativecommons.org/publicdomain/mark/1.0/" }
      genre { ["Rare books"] }
      date_of_work { Work::DateOfWork.new(start: "2019") }
      format { ["text"] }
    end

    # shortcut for create(:work, :published) since we do it a lot
    factory :public_work, traits: [:published] do
    end

    trait :with_complete_metadata do
      place {
        [
          Work::Place.new({"value"=>"Place of interview", "category"=>"place_of_interview"}),
          Work::Place.new({"value"=>"Place of Manufacture", "category"=>"place_of_manufacture"})
        ]
      }
      genre {
        ["Lithographs"]
      }
      type {
        'Work'
      }
      digitization_funder {
        'Daniel Sanford'
      }
      position {
        1
      }
      extent {
        ["0.75 in. H x 2.5 in. W", "80 cm L x 22 cm Diam."]
      }
      format {
        ["image", "mixed_material"]
      }
      medium {
        ["Audiocassettes", "Celluloid", "Dye"]
      }
      rights {
        "http://rightsstatements.org/vocab/NoC-US/1.0/"
      }
      creator {
        [
          Work::Creator.new({"value"=>"After 1", "category"=>"after"}),
          Work::Creator.new({"value"=>"Author 1", "category"=>"author"}),
          Work::Creator.new({"value"=>"Contributor 1", "category"=>"contributor"}),
        ]
      }

      provenance {
        <<~HEREDOC
          This is a provenance[1].

          NOTES

          [1] This is a note.
        HEREDOC
      }

      subject {
        ["Integrated Circuits"]
      }
      language {
        ["Latvian", "Lithuanian", "Estonian"]
      }
      admin_note {
        "Admin Note"
      }
      department {
        "Center for Oral History"
      }
      description {
        "Description 1"
      }
      inscription {
        [
          Work::Inscription.new({"text"=>"Inscription text 1", "location"=>"Inscription location 1"}),
          Work::Inscription.new({"text"=>"Inscription text 2", "location"=>"Inscription location 2"}),
          Work::Inscription.new({"text"=>"Inscription text 3", "location"=>"Inscription location 3"})
        ]
      }
      related_link {
        [
          {
            url: "https://sciencehistory.org/some_biography",
            category: "institute_biography",
            label: "Joe Schmoe"
          }
        ]
      }
      date_of_work {
        [
          Work::DateOfWork.new({
            "note"=>"Note 1",
            "start"=>"2014-01-01",
            "finish"=>"2014-01-02",
            "start_qualifier"=>"before",
            "finish_qualifier"=>"circa",
          }),
          Work::DateOfWork.new({
            "note"=>"Note 2",
            "start"=>"2014-02-03",
            "finish"=>"2014-02-04",
            "start_qualifier"=>"before",
            "finish_qualifier"=>"circa",
          }),
          Work::DateOfWork.new({
            "note"=>"Note 3",
            "start"=>"2014-03-05",
            "finish"=>"2014-03-06",
            "start_qualifier"=>"before",
            "finish_qualifier"=>"circa",
          }),
        ]
      }
      file_creator {
        "Center for Oral History"
      }
      rights_holder {
        "Rights Holder"
      }
      additional_title {
        ["Additional Title 1",  "Additional Title 2"]
      }
      additional_credit {
        [
          Work::AdditionalCredit.new({"name"=>"Douglas Lockard", "role"=>"photographed_by"}),
          Work::AdditionalCredit.new({"name"=>"Mark Backrath",   "role"=>"photographed_by"})
        ]
      }
      physical_container {
        Work::PhysicalContainer.new({"box"=>"Box", "page"=>"Page", "part"=>"Part", "folder"=>"Folder", "volume"=>"Volume", "shelfmark"=>"Shelfmark", "reel"=>"Reel"})
      }
      series_arrangement {
        ["Series arrangement 1", "Series arrangement 2"]
      }


    end

    trait :with_assets do
      transient do
        asset_count { 1 }
      end

      after(:build) do |work, evaluator|
        evaluator.asset_count.times do |i|
          work.members << build(:asset, position: i+1, published: work.published?)
        end
      end
    end

    trait :with_collection do
      transient do
        collection_count { 1 }
      end

      after(:build) do |work, evaluator|
        evaluator.collection_count.times do
          work.contained_by << build(:collection)
        end
      end
    end

    factory :oral_history_work do
      title  { "Oral history interview with William John Bailey" }
      external_id {
        [
          {'category' => 'bib', 'value' => 'b1043559'},
          {'category' => 'interview', 'value' => '0012'}
        ]
      }
      creator {
        [
          {category: "interviewee", value:"Bailey, William John, 1921-1989"},
          {category: "interviewer", value:"Bohning, James J."}
        ]
      }
      date_of_work { [ Work::DateOfWork.new(start: "1986-06-03") ] }
      rights { "https://creativecommons.org/licenses/by-nc-nd/4.0/" }
      place  { [{category: "place_of_interview", value:"University of Maryland, College Park"}] }
      format { ['text'] }
      genre { ["Oral histories"] }
      extent { ['50 pages'] }
      language { ['English'] }
      department { 'Center for Oral History' }
      created_at { DateTime.now }

      oral_history_content {
        OralHistoryContent.new(
          interviewee_biographies: [build(:interviewee_biography)],
          interviewer_profiles:    [build(:interviewer_profile)]
        )
      }

      # have to override published trait from parent factory, to make sure we still
      # have genre Oral histories! And also let's have some a member list more suitable
      # for oral history
      trait :published do
        published { true}
        published_at { Time.now - 86400}
        members { [ build(:asset_with_faked_file, :pdf, published: true) ] }
        genre { ["Oral histories"] }
      end

      trait :public_files do
        members {[
          build(:asset_with_faked_file, :pdf, published: true, title: 'transcript', role: "transcript"),
          build(:asset_with_faked_file, :mp3,
                  title: "audio_recording.mp3",
                  published: true,
                  faked_filename: "#{generate(:oh_filename)}.mp3",
                  faked_size: 21.2.megabytes,
                  faked_derivatives: {} ),
        ]}
      end

      trait :combined_derivative do
        transient do
          num_audio_files { 2 }
        end


        members {[
          build(:asset_with_faked_file, :pdf, published: true, title: 'transcript', role: "transcript"),
        ]}

        after(:build) do |work, evaluator|
          evaluator.num_audio_files.times do |i|
            work.members << build(:asset_with_faked_file, :flac,
                              title: "audio_recording#{i}.flac",
                              published: true,
                              faked_filename: "#{generate(:oh_filename)}.mp3",
                              faked_size: 10.megabytes,
                              faked_derivatives: {} )
          end

          work.save! # don't know why, annoying for performance, but our code requires it to be saved
          work.oral_history_content!.set_combined_audio_m4a!(File.open(Rails.root + "spec/test_support/audio/5-seconds-of-silence.m4a"))

          service = CombinedAudioDerivativeCreator.new(work)
          work.oral_history_content.combined_audio_fingerprint = service.fingerprint
          work.oral_history_content.combined_audio_derivatives_job_status = "succeeded"

          work.oral_history_content.combined_audio_component_metadata = { start_times: service.generate.start_times }
        end
      end

      trait :available_by_request do
        transient do
          available_by_request_mode { :manual_review }
        end

        members {[
          build(:asset_with_faked_file, :pdf, published: true, title: 'Front matter', role: "front_matter"),
          build(:asset_with_faked_file, :mp3,
                  title: "audio_recording.mp3",
                  published: false,
                  oh_available_by_request: true,
                  faked_filename: "#{generate(:oh_filename)}.mp3",
                  faked_size: 21.2.megabytes,
                  faked_derivatives: {} ),
          build(:asset_with_faked_file, :pdf, title: "transcript.pdf", published: false, role: "transcript", oh_available_by_request: true)
        ]}
        after(:build) do |work, evaluator|
          work.representative = work.members.to_a.find {|w| w.published? } if work.representative.nil?
          work.oral_history_content!.available_by_request_mode = evaluator.available_by_request_mode
        end
      end

      trait :available_by_request_flac do
        available_by_request

        members {[
          build(:asset_with_faked_file, :pdf, published: true, title: 'Front matter'),
          build(:asset_with_faked_file, :flac,
            title: "smith_j_0001_1_1.flac",
            faked_filename: "#{generate(:oh_filename)}.flac",
            faked_size: 190.4.megabytes,
            published: false,
            oh_available_by_request: true,
            faked_derivatives: {
              m4a: create(:stored_uploaded_file,
                            file: File.open((Rails.root + "spec/test_support/audio/5-seconds-of-silence.m4a").to_s),
                            size: 12.4.megabytes,
                            content_type: "audio/mp4")
            }
          ),
          build(:asset_with_faked_file, :pdf, title: "transcript.pdf", published: false, oh_available_by_request: true)
        ]}
      end

      trait :ohms_xml do
        transient do
          ohms_xml_text { File.read(Rails.root + "spec/test_support/ohms_xml/legacy/smythe_OH0042.xml") }
        end
        after(:build) do |work, evaluator|
          work.oral_history_content.ohms_xml_text = evaluator.ohms_xml_text
        end
      end
    end

    factory :video_work do
      title  { "Video work" }
      format { ['moving_image'] }
      created_at { DateTime.now }
      date_of_work { [ Work::DateOfWork.new(start: "1986-06-03") ] }
      rights { "https://creativecommons.org/licenses/by-nc-nd/4.0/" }
      department { "Archives" }
      members { [ build(:asset_with_faked_file, :video, published: true) ] }

      trait :published do
        members { [ build(:asset_with_faked_file, :video, published: true) ] }
        published { true}
        published_at { Time.now - 86400}
        genre { ["Video Recordings"] }
      end

      trait :with_poster_frame do
        members { [
          # video
          build(:asset_with_faked_file, :video, published: true),
          # poster frame:
          build(:asset_with_faked_file, published: true)
        ] }
        # We use the representative as both the search results thumbnail *and* the poster frame.
        representative { members[1] }
        published { true }
        published_at { Time.now - 86400}
        genre { ["Video Recordings"] }
      end
    end
  end
end
