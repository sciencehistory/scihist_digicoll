require 'rails_helper'

RSpec.describe GoogleArtsAndCultureSerializer do
  let!(:work_1) do
    create(
      :public_work,
      title: "Work One",
      members: [
        create(:asset_with_faked_file, faked_content_type: "image/tiff")
      ]
    )
  end

  let!(:work_2) do
    create(
      :public_work,
      title: "Work Two",
      members: [
        create(:asset_with_faked_file, faked_content_type: "image/tiff"),
        create(:asset_with_faked_file, faked_content_type: "image/tiff")
      ]
    )
  end

  let(:scope)       { Work.where(id: [work_1.id, work_2.id]) }
  let(:serializer)  { described_class.new(scope) }

  describe "#initialize" do
    it "uses all attribute keys by default" do
      s = described_class.new(scope)
      all_keys = s.all_attributes.keys

      expect(
        s.instance_variable_get(:@attribute_keys)
      ).to match_array(all_keys)
    end

    it "restricts to a provided set of columns" do
      s = described_class.new(scope, columns: [:friendlier_id, :title, :filespec])
      expect(
        s.instance_variable_get(:@attribute_keys)
      ).to eq([:friendlier_id, :title, :filespec])
    end
  end

  describe "#all_attributes" do
    it "maps known keys to Google Arts & Culture column labels" do
      attrs = serializer.all_attributes
      expect(attrs[:friendlier_id]).to eq('itemid')
      expect(attrs[:subitem_id]).to eq('subitemid')
      expect(attrs[:title]).to eq('title')
      expect(attrs[:filespec]).to eq('filespec')
      expect(attrs[:filetype]).to eq('filetype')
    end
  end

  describe "#array_attributes" do
    it "returns an array of multi-valued attribute names as strings" do
      array_attrs = serializer.array_attributes
      expect(array_attrs).to include('subject', 'creator', 'medium', 'extent')
      expect(array_attrs).to all(be_a(String))
    end
  end

  describe "#attribute_methods" do
    it "returns a hash of procs keyed by attribute name" do
      methods_hash = serializer.attribute_methods

      expect(methods_hash).to be_a(Hash)
      expect(methods_hash.keys).to include(:title)

      result = methods_hash[:title].call(work_1)
      expect(result).to eq(work_1.title)
    end
  end

  describe "#to_a" do
    let(:rows) { serializer.to_a }

    it "returns an array of rows, starting with a title row" do
      expect(rows).to be_an(Array)
      expect(rows.first).to eq(serializer.title_row)
      # At least one data row for our works
      expect(rows.size).to be >= 1
    end
  end

  describe "#csv_tempfile" do
    it "returns a Tempfile containing CSV data" do
      tempfile = serializer.csv_tempfile

      expect(tempfile).to be_a(Tempfile)
      contents = File.read(tempfile.path)
      expect(contents).to include("itemid") # header
    ensure
      tempfile.close
      tempfile.unlink
    end
  end

  describe "#title_row" do
    it "uses the attribute_keys and all_attributes mapping" do
      title_row = serializer.title_row
      expect(title_row).to be_an(Array)
      expect(title_row).to eq ["itemid",
        "subitemid",
        "orderid",
        "title",
        "filespec",
        "filetype",
        "relation:text",
        "relation:url",
        "publisher",
        "dateCreated:start",
        "dateCreated:end",
        "dateCreated:display",
        "art=genre#0",
        "description",
        "rights"
      ]
    end
  end

  describe "#work_row" do
    it "returns a flattened array of values for a work" do
      row = serializer.work_row(work_1)
      expect(row).to be_an(Array)
      expect(row.length).to eq(serializer.title_row.length)
      expect(row).to eq [
        work_1.friendlier_id, "", "", "Work One", "", "Sequence", "Science History Institute Digital Collections",
        "http://127.0.0.1/works/#{work_1.friendlier_id}", "", "2019-01-01", "2019-12-31", "2019",
        "Rare books", "", ""
      ]
    end
  end

  describe "#single_asset_work_row" do
    it "uses asset-specific values for filespec/filetype when there is one asset" do
      assets = serializer.members_to_include(work_1)
      row    = serializer.single_asset_work_row(work_1, assets.first)
      expect(row).to be_an(Array)
      # We can at least assert it has the same number of columns as title_row
      expect(row.length).to eq(serializer.title_row.length)
      expect(row).to eq [
        work_1.friendlier_id,
        "",
        "",
        "Work One",
        "work_one_#{work_1.friendlier_id}_#{work_1.members.first.friendlier_id}.jpg",
        "Image",
        "Science History Institute Digital Collections",
        "http://127.0.0.1/works/#{work_1.friendlier_id}",
        "",
        "2019-01-01",
        "2019-12-31",
        "2019",
        "Rare books",
        "",
        ""
      ]
    end
  end

  describe "#work_value_for_attribute_key" do
    it "extracts a value (or padded array) for a given key" do
      value = serializer.work_value_for_attribute_key(work_1, :title)

      expect(value).to be_a(String).or be_an(Array)
    end
  end

  describe "#standard_asset_values" do
    let(:asset) { serializer.members_to_include(work_1).first }
    let(:vals)  { serializer.standard_asset_values(asset) }

    it "returns a hash with standard keys" do
      expect(vals).to include(:friendlier_id, :subitem_id, :order_id, :title, :filespec, :filetype)
    end

    it "includes the parent's friendlier_id" do
      expect(vals[:friendlier_id]).to eq(asset.parent.friendlier_id)
    end
  end

  describe "#asset_row" do
    let(:asset) { serializer.members_to_include(work_2).first }

    it "returns a flattened row corresponding to the asset" do
      row = serializer.asset_row(asset)

      expect(row).to be_an(Array)
      expect(row.length).to eq(serializer.title_row.length)
      expect(row).to eq([
        asset.parent.friendlier_id, asset.friendlier_id, "", "Test title", "work_two_#{asset.parent.friendlier_id}_#{asset.friendlier_id}.jpg",
        "Image", "", "", "", "", "", "", "", "", ""
      ])
    end
  end

  describe "#column_counts" do
    it "returns a hash keyed by array_attributes" do
      counts = serializer.column_counts
      expect(counts).to be_a(Hash)
      serializer.array_attributes.each do |key|
        expect(counts).to have_key(key.to_s)
      end
      expect(counts.symbolize_keys).to eq({
        subject: 0,
        external_id: 4,
        additional_title: 0,
        genre: 1,
        creator: 0,
        medium: 0,
        extent: 0,
        place: 0,
        format: 1
      })
    end
  end

  describe "#column_max_arel" do
    it "returns an Arel SQL expression" do
      arel = serializer.column_max_arel("subject")
      expect(arel).to be_a(Arel::Nodes::SqlLiteral)
      expect(arel).to eq "max(jsonb_array_length(kithe_models.json_attributes -> 'subject'))"
    end
  end

  describe "#scalar_or_array" do
    it "returns no_value when input is nil" do
      result = serializer.scalar_or_array(nil, count_of_columns_needed: 2)
      expect(result).to eq(serializer.no_value)
    end

    it "returns the string untouched when given a string" do
      result = serializer.scalar_or_array("foo", count_of_columns_needed: 2)
      expect(result).to eq("foo")
    end

    it "pads an array up to the expected length" do
      result = serializer.scalar_or_array(["a"], count_of_columns_needed: 3)
      expect(result).to be_an(Array)
      expect(result).to eq ['a', '', '']
    end

    it "raises when given more values than allowed" do
      expect {
        serializer.scalar_or_array(["a", "b", "c"], count_of_columns_needed: 2)
      }.to raise_error("Too many values")
    end
  end

  describe "#pad_array" do
    it "pads an array to a target length using the given padding value" do
      array = ["x"]
      padded = serializer.pad_array(array, 3, "PAD")
      expect(padded).to eq(["x", "PAD", "PAD"])
    end
  end
end
