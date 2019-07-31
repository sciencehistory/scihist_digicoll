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
    zip_file = WorkZipCreator.new(work).create

    found_entries = []

    Zip::File.open(zip_file.path) do |zip_file|
      expect(zip_file.comment).to match(/Science History Institute.*#{work.title}.*#{work.friendlier_id}/m)

      zip_file.each do |entry|
        found_entries << { name: entry.name, size: entry.size}
      end
    end

    expect(found_entries.size).to eq 4
    expect(found_entries.find { |e| e[:name] == "about.txt"}).not_to be nil
    expect(found_entries.all? { |h| h[:size] > 0 }).to be true
  ensure
    if zip_file
      zip_file.close
      zip_file.unlink
    end
  end

  describe "with callback" do
    let(:callback_spy) { spy("callback") }

    it "triggers" do
      zip_file = WorkZipCreator.new(work, callback: callback_spy).create

      expect(callback_spy).to have_received(:call).with(progress_total: 3, progress_i: 1)
      expect(callback_spy).to have_received(:call).with(progress_total: 3, progress_i: 3)
    ensure
      if zip_file
        zip_file.close
        zip_file.unlink
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
      zip_file = WorkZipCreator.new(work).create

      found_entries = []

      Zip::File.open(zip_file.path) do |zip_file|
        expect(zip_file.comment).to match(/Science History Institute.*#{work.title}.*\/works\/#{work.friendlier_id}/m)

        zip_file.each do |entry|
          found_entries << { name: entry.name, size: entry.size}
        end
      end

      expect(found_entries.size).to eq 2 # one file plus about.txt
    end
  end
end
