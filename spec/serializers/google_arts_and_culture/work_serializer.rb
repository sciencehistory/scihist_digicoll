require 'rails_helper'

RSpec.describe GoogleArtsAndCulture::WorkSerializer do
  let!(:work) do
    create(
      :public_work,
      members: [
        create(:asset_with_faked_file, faked_content_type: "image/tiff", position: 0),
        create(:asset_with_faked_file, faked_content_type: "image/tiff", position: 1),
        create(:asset_with_faked_file, faked_content_type: "image/tiff", position: 2, published: false),
        create(:asset_with_faked_file, faked_content_type: "application/pdf", position: 3),
        create(:asset_with_faked_file, published: false, position: 4),
        create(:work, published: false, position: 5)
      ]
    )
  end

  let(:assets) { work.members.to_a }


  let(:column_counts) do
    {
      "subject" => 4,
      "external_id" => 2,
      "additional_title" => 1,
      "genre" => 2,
      "creator" => 2,
      "medium" => 0,
      "extent" => 2,
      "place" => 1,
      "format" => 2
    }
  end
  
  let(:attribute_keys) do
    [
      :friendlier_id,
      :subitem_id,
      :order_id,
      :title,
      :additional_title,
      :file_name,
      :filetype,
      :url_text,
      :url,
      :creator,
      :publisher,
      :subject,
      :extent,
      :min_date,
      :max_date,
      :date_of_work,
      :place,
      :medium,
      :genre,
      :description,
      :rights,
      :rights_holder
    ]
  end

  let(:serializer) { described_class.new(work, attribute_keys:attribute_keys, column_counts:column_counts) }

  describe "#members_to_include" do
    it "returns a collection of public tiff assets for a work" do
      result = serializer.members_to_include
      expect(result).to be_an(Array)
      expect(result.count).to eq 2
      expect(result.map(&:content_type) == ["image/tiff", "image/tiff"]).to be true
      expect(result.map(&:type) == ["Asset", "Asset"]).to be true
    end
  end


  describe "work methods" do
    before do
      allow(serializer).to receive(:test_mode).and_return(true)
    end

    let!(:work) do
      create(:work, :with_complete_metadata,
        creator_attributes: {
          "0"=>{"category"=> "author",     "value"=>"author_1"    },
          "1"=>{"category"=> "author",     "value"=>"author_2"    },
          "2"=>{"category"=> "publisher",  "value"=>"publisher" }
        }
      )
    end

    describe "#subitem_id" do
      it "returns n/a" do
        expect(serializer.subitem_id).to eq "N/A"
      end
    end

    describe "#file_name" do
      it "returns n/a" do
        expect(serializer.file_name).to eq "N/A"
      end
    end

    describe "#order_id" do
      it "returns n/a" do
        expect(serializer.order_id).to eq "N/A"
      end
    end

    describe "#url_text" do
      it "returns boilerplate text" do
        expect(serializer.url_text).to eq 'Science History Institute Digital Collections'
      end
    end

    describe "#url" do
      it "returns URL of work" do
        expect(serializer.url).to eq "#{ScihistDigicoll::Env.lookup!(:app_url_base)}/works/#{work.friendlier_id}"
      end
    end

    describe "#external_id" do
      it "returns external_id" do
        expect(serializer.external_id).to eq ["Past Perfect ID 1", "Sierra Bib Number 1", "Sierra Bib Number 2", "Accession Number 1"]
      end
    end

    describe "#creator" do
      it "returns creator" do
        expect(serializer.creator).to eq ["author_1", "author_2"]
      end
    end

    describe "#publisher" do
      it "returns publisher" do
        expect(serializer.publisher).to eq "publisher"
      end
    end

    describe "#place" do
      it "returns place" do
        expect(serializer.place).to eq ["Place of interview", "Place of Manufacture"]
      end
    end

    describe "#filetype" do
      it "returns Sequence" do
        expect(serializer.filetype).to eq "Sequence"
      end
    end

    describe "#min_date" do
      it "returns date" do
        expect(serializer.min_date).to eq "2014-01-01"
      end
    end

    describe "#max_date" do
      it "returns date" do
        expect(serializer.min_date).to eq "2014-01-01"
      end
    end

    describe "#date_of_work" do
      it "returns all dates in a single string" do
        expect(serializer.date_of_work).to eq "Before 2014-Jan-01 – circa 2014-Jan-02 (Note 1); Before 2014-Feb-03 – circa 2014-Feb-04 (Note 2); Before 2014-Mar-05 – circa 2014-Mar-06 (Note 3)"
      end
    end

    describe "#description" do
      it "returns description" do
        expect(serializer.description).to eq "Description 1"
      end
    end

    describe "#physical_container" do
      it "returns physical_container" do
        expect(serializer.physical_container).to eq ["Box: Box", "Page: Page", "Part: Part", "Folder: Folder", "Volume: Volume", "Shelfmark: Shelfmark", "Reel: Reel"]
      end
    end

    describe "#additional_credit" do
      it "returns additional_credit" do
        expect(serializer.additional_credit).to eq ["photographed_by:Douglas Lockard", "photographed_by:Mark Backrath"]
      end
    end

    describe "#created" do
      it "returns a date string" do
        expect(serializer.created).to be_a String
      end
    end

    describe "#last_modified" do
      it "returns a date string" do
        expect(serializer.last_modified).to be_a String
      end
    end
  end
end
