FactoryBot.define do
  factory :work, class: Work do
    title { 'Test title' }
    external_id do [
        Work::ExternalId.new({"value"=>"Past Perfect ID 1",   "category"=>"object"}),
        Work::ExternalId.new({"value"=>"Sierra Bib Number 1", "category"=>"bib"   }),
        Work::ExternalId.new({"value"=>"Sierra Bib Number 2", "category"=>"bib"   }),
        Work::ExternalId.new({"value"=>"Accession Number 1",  "category"=>"accn"  })
      ]
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
      source {
        'Source'
      }
      creator {
        [
          Work::Creator.new({"value"=>"After 1", "category"=>"after"}),
          Work::Creator.new({"value"=>"Author 1", "category"=>"author"}),
          Work::Creator.new({"value"=>"Contributor 1", "category"=>"contributor"}),
        ]
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
          work.members << build(:asset, position: i+1)
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

  end
end
