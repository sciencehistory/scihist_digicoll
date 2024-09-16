require 'rails_helper'

describe WorkDownloadOptions do
  let(:asset) { create(:asset_with_faked_file) }
  let(:service) { WorkDownloadOptions.new(work: work) }
  let(:options) { service.options }


  describe "with all image files" do

    let(:work) do
      create(:public_work, members: [asset, build(:asset_with_faked_file), build(:asset_with_faked_file)])
    end

    it "renders whole-work download options" do
      expect(options.length).to eq 2

      zip_option = options.find { |o| o.analyticsAction == "download_zip"}
      expect(zip_option).to be_present
      expect(zip_option.url).to eq "#"
      expect(zip_option.work_friendlier_id).to eq work.friendlier_id
      expect(zip_option.subhead).to eq "of full-sized JPGs"
      expect(zip_option.label).to eq "ZIP"
      expect(zip_option.data_attrs).to be_present
      expect(zip_option.data_attrs[:trigger]).to eq "on-demand-download"
      expect(zip_option.data_attrs[:derivative_type]).to eq "zip_file"
      expect(zip_option.data_attrs[:work_id]).to eq work.friendlier_id
      expect(zip_option.data_attrs[:analytics_category]).to eq "Work"
      expect(zip_option.data_attrs[:analytics_action]).to eq "download_zip"
      expect(zip_option.data_attrs[:analytics_label]).to eq work.friendlier_id

      pdf_option = options.find { |o| o.analyticsAction == "download_pdf"}
      expect(pdf_option).to be_present
      expect(pdf_option.url).to eq "#"
      expect(pdf_option.work_friendlier_id).to eq work.friendlier_id
      expect(pdf_option.subhead).to be nil
      expect(pdf_option.label).to eq "PDF"
      expect(pdf_option.data_attrs).to be_present
      expect(pdf_option.data_attrs[:trigger]).to eq "on-demand-download"
      expect(pdf_option.data_attrs[:derivative_type]).to eq "pdf_file"
      expect(pdf_option.data_attrs[:work_id]).to eq work.friendlier_id
      expect(pdf_option.data_attrs[:analytics_category]).to eq "Work"
      expect(pdf_option.data_attrs[:analytics_action]).to eq "download_pdf"
      expect(pdf_option.data_attrs[:analytics_label]).to eq work.friendlier_id
    end
  end

  describe "unpublished parent work" do
    let(:work) do
      create(:work, published: false, members: [build(:asset_with_faked_file), build(:asset_with_faked_file)])
    end

    # whole work download options are cached publically, they only include public
    # members, and don't make sense on non-public work, and sometimes create errors
    # if clicked there.
    it "does not include whole-work download options" do
      expect(options).to be_empty
    end
  end
end
