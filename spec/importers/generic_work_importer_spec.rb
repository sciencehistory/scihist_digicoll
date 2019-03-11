require 'rails_helper'




RSpec.describe Importers::GenericWorkImporter do
  let(:metadata) do
    {
      "id"=>"8049g504g",
      "head" => [
        "#<ActiveTriples::Resource:0x0000558a2682fa68>"
      ],
      "tail" => [
        "#<ActiveTriples::Resource:0x0000558a26826030>"
      ],
      "depositor"=> "njoniec@sciencehistory.org",
      "title" => [
        "Adulterations of food; with short processes for their detection."
      ],
      "date_uploaded"=> "2019-02-08T20:45:54+00:00",
      "date_modified"=> "2019-02-08T20:49:43+00:00",
      "state" => "#<ActiveTriples::Resource:0x0000558a2d321088>",
      "part_of" => [
        "#<ActiveTriples::Resource:0x0000558a2681aff0>"
      ],
      "identifier" => [
        "bib-b1075796"
      ],
      "author" => [
        "Atcherley, Rowland J."
      ],
      "credit_line" => [
        "Courtesy of Science History Institute"
      ],
      "division" => "",
      "file_creator" =>  "",
      "physical_container" =>  "",
      "rights_holder" =>  "",
      "access_control_id" =>  "90cb04df-61a7-4d61-84e2-130fc7ddbee3",
      "access_control" => "private",
      "representative_id" =>  "2v23vv55g",
      "thumbnail_id" =>  "2v23vv55g",
      "admin_set_id" =>  "admin_set/default",
      "child_ids" =>  [
        "kp78gh433",
        "1v53jz06w",
        "nk322f35j",
        "0r9674786",
        "6q182m18c",
        "1831cm25h",
        "8623hz81w"
      ],
      "medium" => ["Vellum"]
    }
  end


  let(:generic_work_importer) { Importers::GenericWorkImporter.new(metadata) }

  it "imports" do
    generic_work_importer.import
    new_work = Work.first

    expect(new_work.title).to match /Adulterations/
    expect(new_work.created_at).to eq(DateTime.parse(metadata["date_uploaded"]))
    expect(new_work.updated_at).to eq(DateTime.parse(metadata["date_modified"]))
    expect(new_work.published?).to be(false)
    expect(new_work.medium).to eq(["Vellum"])
  end


  context "public work" do
    let(:metadata) do
      {
        "id"=>"8049g504g",
        "head" => [
          "#<ActiveTriples::Resource:0x0000558a2682fa68>"
        ],
        "tail" => [
          "#<ActiveTriples::Resource:0x0000558a26826030>"
        ],
        "depositor"=> "njoniec@sciencehistory.org",
        "title" => [
          "Adulterations of food; with short processes for their detection."
        ],
        "date_uploaded"=> "2019-02-08T20:45:54+00:00",
        "date_modified"=> "2019-02-08T20:49:43+00:00",
        "state" => "#<ActiveTriples::Resource:0x0000558a2d321088>",
        "part_of" => [
          "#<ActiveTriples::Resource:0x0000558a2681aff0>"
        ],
        "identifier" => [
          "bib-b1075796"
        ],
        "author" => [
          "Atcherley, Rowland J."
        ],
        "credit_line" => [
          "Courtesy of Science History Institute"
        ],
        "division" => "",
        "file_creator" =>  "",
        "physical_container" =>  "",
        "rights_holder" =>  "",
        "access_control_id" =>  "90cb04df-61a7-4d61-84e2-130fc7ddbee3",
        "access_control" => "public",
        "representative_id" =>  "2v23vv55g",
        "thumbnail_id" =>  "2v23vv55g",
        "admin_set_id" =>  "admin_set/default",
        "child_ids" =>  [
          "kp78gh433",
          "1v53jz06w",
          "nk322f35j",
          "0r9674786",
          "6q182m18c",
          "1831cm25h",
          "8623hz81w"
        ]
      }
    end

    it "imports as published" do
      generic_work_importer.import
      new_work = Work.first

      expect(new_work.published?).to be(true)
    end

    describe "with existing item" do
      let!(:existing_item) { FactoryBot.create(:work, friendlier_id: metadata["id"], title: "old title", published: false)}

      it "imports and updates data" do
        generic_work_importer.import

        expect(Work.where(friendlier_id: metadata["id"]).count).to eq(1)
        item = Work.find_by_friendlier_id!(metadata["id"])

        expect(item.title).to eq "Adulterations of food; with short processes for their detection."
        expect(item.published?).to be(true)
      end
    end
  end
end
