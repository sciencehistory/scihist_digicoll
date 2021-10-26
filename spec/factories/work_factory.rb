FactoryBot.define do
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
      members {  [ build(:asset_with_faked_file, published: true) ] }
      department { "Library" }
      rights { "http://creativecommons.org/publicdomain/mark/1.0/" }
      genre { ["Rare books"] }
      date_of_work { Work::DateOfWork.new(start: "2019") }
      format { ["text"] }
      after(:build) do |work|
        work.representative = work.members.first
        work.published = true
        work.save!
      end
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
        "http://rightsstatements.org/vocab/NoC-CR/1.0/"
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
      exhibition {
        ["Making Modernity", "Lobby 2017"]
      }
      project {
        ["REACH Ambler", "Science and Disability"]
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
      related_url {
        ["http://www.nytimes.com"]
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
        Work::PhysicalContainer.new({"box"=>"Box", "page"=>"Page", "part"=>"Part", "folder"=>"Folder", "volume"=>"Volume", "shelfmark"=>"Shelfmark"})
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
          interviewee_biographies: [build(:interviewee_biography)]
        )
      }

      trait :available_by_request do
        transient do
          available_by_request_mode { :manual_review }
        end

        members {[
          build(:asset_with_faked_file, :pdf, published: true, title: 'Front matter'),
          build(:asset_with_faked_file, :mp3, title: "audio_recording.mp3", published: false, oh_available_by_request: true),
          build(:asset_with_faked_file, :pdf, title: "transcript.pdf", published: false, oh_available_by_request: true)
        ]}
        after(:build) do |work, evaluator|
          work.representative = work.members.to_a.find {|w| w.published? }
          work.oral_history_content!.available_by_request_mode = evaluator.available_by_request_mode
        end
      end

      trait :ohms_xml do
        transient do
          ohms_xml_text { File.read(Rails.root + "spec/test_support/ohms_xml/smythe_OH0042.xml") }
        end
        after(:build) do |work, evaluator|
          work.oral_history_content.ohms_xml_text = evaluator.ohms_xml_text
        end
      end

      trait :published do
        members do
          [ build(:asset_with_faked_file, :pdf, published: true) ]
        end
        after(:build) do |work|
          work.update(published:true)
        end
      end
      
    end
  end
end
