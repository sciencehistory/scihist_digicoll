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

  let!(:work_3) do
    create(
      :private_work,
      members: [
        create(:asset_with_faked_file, faked_content_type: "image/tiff")
      ]
    )
  end


  let(:scope) { Work.where(id: [work_1.id, work_2.id, work_3.id]) }

  describe "#initialize" do
    it "stores scope and optional callback" do
      creator  = described_class.new(scope)
      expect(creator.original_scope).to eq(scope)
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

  describe "#metadata_csv_tempfile" do
    let(:creator) { described_class.new(scope) }
    it "returns a hash of filenames and downloadable file objects; does not include unpublished works" do
      file_hash = creator.file_hash
      expect(file_hash.keys).to contain_exactly(
        "#{DownloadFilenameHelper.filename_base_from_parent(work_1.members.first)}.jpg",
        "#{DownloadFilenameHelper.filename_base_from_parent(work_2.members.first)}.jpg"
      )
      expect(file_hash.values.all? {|f| f.is_a? AssetUploader::UploadedFile}).to be true
    end
  end

  describe "#title_row" do
    let(:scope) { Work.where(id: [work_1.id, work_2.id, work_3.id, work_4.id]) }
    let(:creator) { described_class.new(scope) }
    let(:work_4) do
      create(:work, :published, :extra_creator_metadata)
    end

    it "organizes complex creator metdata into columns" do
      expect(creator.title_row.sort).to eq %w[art=genre#0 contributor#0 creator#0 creator#1
        creator#10 creator#11 creator#12 creator#13 creator#14 creator#15 creator#16 creator#17
        creator#18 creator#19 creator#2 creator#20 creator#21 creator#22 creator#3 creator#4
        creator#5 creator#6 creator#7 creator#8 creator#9 customtext:additional_title#0
        customtext:additional_title#1 customtext:addressee#0 customtext:after#0
        customtext:artist#0 customtext:attributed_to#0 customtext:author#0 customtext:engraver#0
        customtext:interviewee#0 customtext:interviewer#0 customtext:manner_of#0
        customtext:manufacturer#0 customtext:photographer#0 customtext:photographer#1
        customtext:photographer#2 customtext:printer#0 customtext:printer_of_plates#0
        customtext:rights_holder customtext:school_of#0 customtext:sponsor#0 customtext:sponsor#1
        dateCreated:display dateCreated:end dateCreated:start description filespec filetype
        format#0 format#1 itemid locationCreated:placename#0 locationCreated:placename#1 medium#0
        medium#1 medium#2 orderid publisher#0 publisher#1 publisher#2 relation:text
        relation:url rights subitemid subject#0 title]
    end
  end

end
