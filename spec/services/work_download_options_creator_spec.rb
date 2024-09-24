require 'rails_helper'

describe WorkDownloadOptionsCreator do
  let(:asset) { create(:asset_with_faked_file) }
  let(:service) { WorkDownloadOptionsCreator.new(work) }
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

  describe "work_source_pdf with derivative" do
    let(:source_pdf_asset) { build(:asset_with_faked_source_pdf) }
    let(:work) do
      create(:public_work, members: [
        source_pdf_asset,
        build(:asset_with_faked_file)
      ])
    end

    it "has original PDF and scaled PDF options" do
      original_option =  options.find { |o| o.label == "Original PDF" }
      expect(original_option).to be_present
      # 10 pages, 80.5 MB
      expect(original_option.subhead).to match /\d+ pages — (\d+\.?)+ [A-Z]{2}/
      expect(original_option.work_friendlier_id).to eq work.friendlier_id
      expect(original_option.url).to include source_pdf_asset.friendlier_id
      expect(original_option.analyticsAction).to eq "download_original"
      expect(original_option.content_type).to eq "application/pdf"

      scaled = options.find { |o| o.label == "Screen-Optimized PDF" }
      expect(scaled).to be_present
      # 124 MB, 150 dpi
      expect(scaled.subhead).to match /150 dpi — (\d+\.?)+ [A-Z]{2}/
      expect(scaled.work_friendlier_id).to eq work.friendlier_id
      expect(scaled.url).to include source_pdf_asset.friendlier_id
      expect(scaled.url).to include AssetUploader::SCALED_PDF_DERIV_KEY.to_s
      expect(scaled.analyticsAction).to eq "download_pdf_screen"
      expect(scaled.content_type).to eq "application/pdf"
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
