require 'rails_helper'
require 'zip'

RSpec.describe GoogleArtsAndCulture::Exporter do
  let!(:work_1) do
    create(
      :public_work,
      members: [
        create(:asset_with_faked_file, faked_content_type: "image/tiff")
      ]
    )
  end

  let!(:work_2) do
    create(
      :public_work,
      members: [
        create(:asset_with_faked_file, faked_content_type: "image/tiff")
      ]
    )
  end

  let(:scope) { Work.where(id: [work_1.id, work_2.id]) }

  describe "#initialize" do
    it "stores scope and optional callback" do
      callback = ->(*) {}
      creator  = described_class.new(scope, callback: callback)
      expect(creator.scope).to eq(scope)
      expect(creator.callback).to eq(callback)
    end
  end

  describe "#metadata_csv_tempfile" do
    let(:creator) { described_class.new(scope) }
    it "returns a Tempfile" do
      tempfile = creator.metadata_csv_tempfile
      expect(tempfile).to be_a(Tempfile)
      expect(File.exist?(tempfile.path)).to be(true)
      expect(File.size(tempfile.path)).to be > 0
    ensure
      tempfile.close
      tempfile.unlink
    end
  end

  describe "#upload_files_to_google_arts_and_culture" do
    let(:creator) { described_class.new(scope) }
    it "enqueues a job to upload the files" do
      expect {
        creator.upload_files_to_google_arts_and_culture_async
      }.to have_enqueued_job(UploadFilesToGoogleArtsAndCultureJob).with { |params|
        {
          work_ids: [work_1.id, work_2.id]
        }
      }
    end
  end
end
