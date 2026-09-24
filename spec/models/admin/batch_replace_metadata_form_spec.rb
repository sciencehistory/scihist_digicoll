require 'rails_helper'

RSpec.describe Admin::BatchReplaceMetadataForm, queue_adapter: :test do
  describe ".field_options" do
    it "includes exactly the allow-listed fields, as [label, name] pairs sorted by label" do
      options = described_class.field_options

      expect(options.map(&:last)).to match_array(described_class::ALLOWED_FIELDS.keys)
      expect(options.map(&:first)).to eq(options.map(&:first).sort)
    end
  end

  describe "validations" do
    it "requires old_value" do
      form = described_class.new(field_name: "description", old_value: "", new_value: "x")
      expect(form.valid?).to be false
      expect(form.errors[:old_value]).to be_present
    end

    it "rejects a real Work attribute that isn't on the allow-list" do
      form = described_class.new(field_name: "format", old_value: "x", new_value: "y")
      expect(form.valid?).to be false
      expect(form.errors[:field_name]).to be_present
    end

    it "requires new_value" do
      form = described_class.new(field_name: "description", old_value: "x", new_value: "")
      expect(form.valid?).to be false
      expect(form.errors[:new_value]).to be_present
    end
  end

  describe "#field_label" do
    it "is the human-readable label for the selected field" do
      form = described_class.new(field_name: "rights_holder")
      expect(form.field_label).to eq("Rights holder")
    end
  end

  describe "#matching_works and #matching_work_count" do
    let!(:matching_work) { create(:work, description: "a widget") }
    let!(:non_matching_work) { create(:work, description: "nothing to see here") }

    it "returns empty when invalid" do
      form = described_class.new(field_name: "not_a_real_field", old_value: "widget", new_value: "gadget")

      expect(form.matching_works.to_a).to eq([])
    end

    it "finds only works whose field exactly matches old_value" do
      form = described_class.new(field_name: "description", old_value: "a widget", new_value: "a gadget")

      expect(form.matching_works).to contain_exactly(matching_work)
      expect(form.matching_work_count).to eq(1)
    end

    it "matches one exact element of an array-of-strings field" do
      work = create(:work, medium: ["Celluloid", "Dye"])

      expect(described_class.new(field_name: "medium", old_value: "Celluloid", new_value: "x").matching_works).to include(work)
      expect(described_class.new(field_name: "medium", old_value: "Cellu", new_value: "x").matching_works).not_to include(work)
    end

    it "matches a nested-model field's exact key_path value" do
      work = create(:work, creator: [Work::Creator.new(value: "Foo Bar", category: "author")])

      expect(described_class.new(field_name: "creator", old_value: "Foo Bar", new_value: "x").matching_works).to include(work)
      # category isn't searched, only value
      expect(described_class.new(field_name: "creator", old_value: "author", new_value: "x").matching_works).not_to include(work)
    end
  end

  describe "#replace!" do
    let!(:work) { create(:work, description: "a widget") }

    it "replaces the value, saves, and enqueues reindexing" do
      form = described_class.new(field_name: "description", old_value: "a widget", new_value: "a gadget")

      expect {
        expect(form.replace!).to be true
      }.to have_enqueued_job(ReindexWorksJob).with([work.id])

      expect(work.reload.description).to eq("a gadget")
    end

    it "does nothing and returns false when invalid" do
      form = described_class.new(field_name: "not_a_real_field", old_value: "a widget", new_value: "a gadget")

      expect(form.replace!).to be false
      expect(work.reload.description).to eq("a widget")
    end

    it "replaces only the exactly-matching element of an array-of-strings field" do
      work.update!(medium: ["Celluloid", "Dye"])
      form = described_class.new(field_name: "medium", old_value: "Celluloid", new_value: "Glass")

      expect(form.replace!).to be true
      expect(work.reload.medium).to eq(["Glass", "Dye"])
    end

    it "replaces only the key_path attribute of a matching element of a nested-model field" do
      work.update!(creator: [
        Work::Creator.new(value: "Foo Bar", category: "author"),
        Work::Creator.new(value: "Someone Else", category: "photographer")
      ])
      form = described_class.new(field_name: "creator", old_value: "Foo Bar", new_value: "New Name")

      expect(form.replace!).to be true
      work.reload
      expect(work.creator.map(&:value)).to eq(["New Name", "Someone Else"])
      expect(work.creator.map(&:category)).to eq(["author", "photographer"])
    end

    it "replaces every matching element (not just the first) and leaves non-matching elements untouched, persisted to the db" do
      work.update!(creator: [
        Work::Creator.new(value: "Foo Bar", category: "author"),
        Work::Creator.new(value: "Someone Else", category: "photographer"),
        Work::Creator.new(value: "Foo Bar", category: "editor") # same value as the first, different category
      ])
      form = described_class.new(field_name: "creator", old_value: "Foo Bar", new_value: "New Name")

      expect(form.replace!).to be true

      # check against a freshly-queried record (not the same Ruby object/instance),
      # and against the raw jsonb bytes, to be sure this was actually persisted and
      # not just mutated on the in-memory object.
      fresh = Work.find(work.id)
      expect(fresh.creator.map { |c| [c.value, c.category] }).to eq([
        ["New Name", "author"],
        ["Someone Else", "photographer"],
        ["New Name", "editor"]
      ])

      raw_creator = ActiveRecord::Base.connection.select_value(
        "select json_attributes -> 'creator' from kithe_models where id = #{ActiveRecord::Base.connection.quote(work.id)}"
      )
      expect(JSON.parse(raw_creator)).to eq([
        { "value" => "New Name", "category" => "author" },
        { "value" => "Someone Else", "category" => "photographer" },
        { "value" => "New Name", "category" => "editor" }
      ])
    end

    context "when a replacement would make a matching work invalid" do
      let!(:work) { create(:work, file_creator: "Center for Oral History") }

      it "rolls back and leaves nothing changed, with an error" do
        form = described_class.new(field_name: "file_creator", old_value: "Center for Oral History", new_value: "not-a-valid-file-creator")

        expect(form.replace!).to be false
        expect(form.errors[:base]).to be_present
        expect(work.reload.file_creator).to eq("Center for Oral History")
      end
    end
  end
end
