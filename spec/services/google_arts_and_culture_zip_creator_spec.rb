# spec/services/google_arts_and_culture_zip_creator_spec.rb
require 'rails_helper'
require 'zip'

RSpec.describe GoogleArtsAndCultureZipCreator do
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

  describe "#metadata_csv_file" do
    let(:creator) { described_class.new(scope) }
    it "returns a Tempfile" do
      tempfile = creator.metadata_csv_file
      expect(tempfile).to be_a(Tempfile)
      expect(File.exist?(tempfile.path)).to be(true)
      expect(File.size(tempfile.path)).to be > 0
    ensure
      tempfile.close
      tempfile.unlink
    end
  end

  describe "#create" do
    let(:creator) { described_class.new(scope) }

    it "returns a Tempfile ready for reading" do
      zip_file = creator.create

      expect(zip_file).to be_present
      expect(zip_file).to be_a(Tempfile)
      expect(zip_file.size).to be > 0
      expect(zip_file.size).to eq(File.size(zip_file.path))
      expect(zip_file.lineno).to eq(0)
    ensure
      if zip_file
        zip_file.close
        zip_file.unlink
      end
    end

    it "builds a zip file that includes a manifest.csv and asset entries" do
      zip_file = creator.create
      entry_names = []

      Zip::File.open(zip_file.path) do |zip|
        zip.each do |entry|
          entry_names << entry.name
        end
      end

      expect(entry_names).to include("manifest.csv")
      # At least one additional file representing an asset
      expect(entry_names.size).to be > 1
    ensure
      if zip_file
        zip_file.close
        zip_file.unlink
      end
    end
  end
end
