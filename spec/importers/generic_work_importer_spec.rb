require 'rails_helper'




RSpec.describe Importers::GenericWorkImporter do
  class ProgressBarStub
    def log(*args)
    end
    def increment(*args)
    end
  end

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

  context "simple work" do
    let(:generic_work_importer) { Importers::GenericWorkImporter.new(metadata, ProgressBarStub.new) }

    it "imports" do
      generic_work_importer.save_item()
      expect(Work.first.title).to match /Adulterations/
    end
  end
end
