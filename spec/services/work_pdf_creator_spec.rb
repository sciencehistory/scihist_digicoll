require 'rails_helper'

describe WorkZipCreator do
  let(:work) do
    create(:work,
      members: [
        create(:asset_with_faked_file),
        create(:asset_with_faked_file),
        create(:work, representative: create(:asset_with_faked_file))
      ]
    )
  end

  it "builds zip" do
    pdf_file = WorkPdfCreator.new(work).create

    reader = PDF::Reader.new(pdf_file.path)
    expect(reader.pages.count).to eq 3

    metadata = reader.info

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
      pdf_file = WorkZipCreator.new(work, callback: callback_spy).create

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
    let(:work) do
      create(:work,
        members: [
          create(:asset_with_faked_file, faked_derivatives: []),
          create(:asset_with_faked_file)
        ]
      )
    end

    it "skips missing files" do
      pdf_file = WorkPdfCreator.new(work).create

      reader = PDF::Reader.new(pdf_file.path)
      expect(reader.pages.count).to eq 1
    ensure
      if pdf_file
        pdf_file.close
        pdf_file.unlink
      end
    end
  end
end
