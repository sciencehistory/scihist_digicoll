# spec/helpers/google_arts_and_culture_serializer_helper_spec.rb
require 'rails_helper'

RSpec.describe GoogleArtsAndCultureSerializerHelper, type: :helper do
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

  describe "#members_to_include" do
    it "returns a collection of public tiff assets for a work" do
      result = helper.members_to_include(work)
      expect(result).to be_an(Array)
      expect(result.count).to eq 2
      expect(result.map(&:content_type) == ["image/tiff", "image/tiff"]).to be true
      expect(result.map(&:type) == ["Asset", "Asset"]).to be true
    end
  end

  describe "asset methods" do
    before do
      allow(helper).to receive(:test_mode).and_return(true)
    end

    let!(:asset) { create(:asset_with_faked_file, faked_content_type: "image/tiff", position: 0, friendlier_id: "abc", parent: create(:work)) }

    describe "#filename_from_asset" do
      it "returns a string filename for the given asset" do
        expect(helper.filename_from_asset(asset)).to eq "test_title_#{asset.parent.friendlier_id}_0_#{asset.friendlier_id}.jpg"
      end
    end

    describe "#asset_filetype" do
      it "uses Image for tiff assets" do
        expect(helper.asset_filetype(asset)).to eq "Image"
      end
    end

    describe "#standard_asset_values" do
      it "returns standard values" do
        expect(helper.standard_asset_values(asset)).to eq({ 
          filespec: "test_title_#{asset.parent.friendlier_id}_0_abc.jpg",
          filetype: "Image",
          friendlier_id: asset.parent.friendlier_id,
          order_id: 0,
          subitem_id: "abc",
          title: "Test title"
        })
      end
    end

    # describe "#asset_row" do
    #   it "returns standard values" do
    #     expect(helper.asset_row(asset)).to eq "N/A"
    #   end
    # end

    describe "#file_to_include" do
      it "returns an uploaded file" do
        expect(helper.file_to_include(asset).class).to eq AssetUploader::UploadedFile
      end
    end    
  end

  describe "work methods" do
    before do
      allow(helper).to receive(:test_mode).and_return(true)
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
        expect(helper.subitem_id(work)).to eq "N/A"
      end
    end
    describe "#filespec" do
      it "returns n/a" do
        expect(helper.filespec(work)).to eq "N/A"
      end
    end
    describe "#order_id" do
      it "returns n/a" do
        expect(helper.order_id(work)).to eq "N/A"
      end
    end
    describe "#url_text" do
      it "returns boilerplate text" do
        expect(helper.url_text(work)).to eq 'Science History Institute Digital Collections'
      end
    end

    describe "#url" do
      it "returns URL of work" do
        expect(helper.url(work)).to eq "#{ScihistDigicoll::Env.lookup!(:app_url_base)}/works/#{work.friendlier_id}"
      end
    end

    describe "#external_id" do
      it "returns external_id" do
        expect(helper.external_id(work)).to eq ["Past Perfect ID 1", "Sierra Bib Number 1", "Sierra Bib Number 2", "Accession Number 1"]
      end
    end

    describe "#creator" do
      it "returns creator" do
        expect(helper.creator(work)).to eq ["author_1", "author_2"]
      end
    end

    describe "#publisher" do
      it "returns publisher" do
        expect(helper.publisher(work)).to eq "publisher"
      end
    end

    describe "#place" do
      it "returns place" do
        expect(helper.place(work)).to eq ["Place of interview", "Place of Manufacture"]
      end
    end

    describe "#filetype" do
      it "returns Sequence" do
        expect(helper.filetype(work)).to eq "Sequence"
      end
    end

    describe "#min_date" do
      it "returns date" do
        expect(helper.min_date(work)).to eq "2014-01-01"
      end
    end

    describe "#max_date" do
      it "returns date" do
        expect(helper.min_date(work)).to eq "2014-01-01"
      end
    end

    describe "#date_of_work" do
      it "returns all dates in a single string" do
        expect(helper.date_of_work(work)).to eq "Before 2014-Jan-01 – circa 2014-Jan-02 (Note 1); Before 2014-Feb-03 – circa 2014-Feb-04 (Note 2); Before 2014-Mar-05 – circa 2014-Mar-06 (Note 3)"
      end
    end

    describe "#description" do
      it "returns description" do
        expect(helper.description(work)).to eq "Description 1"
      end
    end

    describe "#physical_container" do
      it "returns physical_container" do
        expect(helper.physical_container(work)).to eq ["Box: Box", "Page: Page", "Part: Part", "Folder: Folder", "Volume: Volume", "Shelfmark: Shelfmark", "Reel: Reel"]
      end
    end

    describe "#additional_credit" do
      it "returns additional_credit" do
        expect(helper.additional_credit(work)).to eq ["photographed_by:Douglas Lockard", "photographed_by:Mark Backrath"]
      end
    end

    describe "#created" do
      it "returns a date string" do
        expect(helper.created(work)).to be_a String
      end
    end

    describe "#last_modified" do
      it "returns a date string" do
        expect(helper.last_modified(work)).to be_a String
      end
    end
  end
end
