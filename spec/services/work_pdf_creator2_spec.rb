require 'rails_helper'

describe WorkPdfCreator2 do
  let(:work) do
    create(:public_work,
      members: [
        create(:asset_with_faked_file, :tiff),
        create(:asset_with_faked_file, :tiff),
        create(:asset_with_faked_file, :flac, title: "skip me"),
        create(:public_work, representative: create(:asset_with_faked_file, :tiff))
      ]
    )
  end

  it "returns working File ready for reading" do
    pdf_file = WorkPdfCreator2.new(work).create

    expect(pdf_file).to be_present
    expect(pdf_file).to be_kind_of(Tempfile)
    expect(pdf_file.size).not_to eq(0)
    expect(pdf_file.size).to eq(File.size(pdf_file.path))
    expect(pdf_file.lineno).to eq(0)
  end

  it "builds PDF" do
    pdf_file = WorkPdfCreator2.new(work).create

    expect(pdf_file).to be_kind_of(Tempfile)
    expect(File.exist?(pdf_file.path)).to be(true)

    reader = PDF::Reader.new(pdf_file.path)
    expect(reader.pages.count).to eq 3
  ensure
    if pdf_file
      pdf_file.close
      pdf_file.unlink
    end
  end

  it "sets metadata on PDF", skip: "feature not currently implemented" do
    pdf_file = WorkPdfCreator2.new(work).create
    reader = PDF::Reader.new(pdf_file.path)

    metadata = reader.info
    expect(metadata).to be_present

    expect(metadata[:Title]).to eq work.title
    expect(metadata[:Creator]).to eq "Science History Institute"
    expect(metadata[:Producer]).to eq "Science History Institute"
    expect(metadata[:CreationDate]).to be_present
    expect(metadata[:Url]).to match %r{/works/#{work.friendlier_id}}
  ensure
    if pdf_file
      pdf_file.close
      pdf_file.unlink
    end
  end

  describe "with callback" do
    let(:callback_spy) { spy("callback") }

    it "triggers" do
      pdf_file = WorkPdfCreator2.new(work, callback: callback_spy).create

      expect(callback_spy).to have_received(:call).with(progress_total: 3, progress_i: 1)
      expect(callback_spy).to have_received(:call).with(progress_total: 3, progress_i: 3)
    ensure
      if pdf_file
        pdf_file.close
        pdf_file.unlink
      end
    end
  end

  describe "with missing derivatives" do
    let(:asset_missing_derivatives) { create(:asset_with_faked_file, :tiff, faked_derivatives: {}) }
    let(:work) do
      create(:work,
        members: [
          asset_missing_derivatives,
          create(:asset_with_faked_file, :tiff)
        ]
      )
    end

    it "raises an exception" do
      expect {
        pdf_file  = WorkPdfCreator2.new(work).create
      }.to raise_error(StandardError, /Can't create combined PDF for asset '#{asset_missing_derivatives.friendlier_id}' with missing :graphiconly_pdf derivative/)
    end
  end

  describe "with no available published images" do
    let(:work) do
      build(:public_work, members: [create(:asset_with_faked_file, published: false)])
    end

    it "raises on create" do
      expect{
        WorkPdfCreator2.new(work).create
      }.to raise_error(WorkPdfCreator2::PdfCreationFailure, /No PDF files to join/)
    end
  end

end
