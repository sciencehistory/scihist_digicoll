require 'rails_helper'

RSpec.describe Admin::BatchReplaceMetadataForm, queue_adapter: :test do
  let(:current_user) { create(:editor_user) }

  describe ".field_options" do
    it "includes exactly the allow-listed fields, as [label, name] pairs sorted by label" do
      options = described_class.field_options

      expect(options.map(&:last)).to match_array(described_class::ALLOWED_FIELDS)
      expect(options.map(&:first)).to eq(options.map(&:first).sort)
    end

    it "labels a nested field by its attribute, unless several of its sub-attributes are allowed" do
      options = described_class.field_options.to_h.invert

      expect(options["creator.value"]).to eq("Creator")
      expect(options["physical_container.box"]).to eq("Physical container: Box")
      expect(options["physical_container.folder"]).to eq("Physical container: Folder")
    end
  end

  describe ".controlled_values" do
    it "has [label, value] pairs, only for allow-listed fields" do
      described_class.controlled_values.each do |field_name, options|
        expect(described_class::ALLOWED_FIELDS).to include(field_name.to_s)
        expect(options).to all(match([a_kind_of(String), a_kind_of(String)]))
      end
    end

    it "has the Work's valid values, with human labels" do
      values = described_class.controlled_values

      expect(values[:format]).to include(["Mixed Material", "mixed_material"])
      expect(values[:genre].map(&:last)).to match_array(Work::ControlledLists::GENRE)
      expect(values[:rights].map(&:last)).to match_array(RightsTerm.all_ids)
    end
  end

  describe "validations" do
    it "requires old_value" do
      form = described_class.new(current_user: current_user, form_params: { field_name: "description", old_value: "", new_value: "x" })
      expect(form.valid?).to be false
      expect(form.errors[:old_value]).to be_present
    end

    it "rejects a real Work attribute that isn't on the allow-list" do
      form = described_class.new(current_user: current_user, form_params: { field_name: "department", old_value: "x", new_value: "y" })
      expect(form.valid?).to be false
      expect(form.errors[:field_name]).to be_present
    end

    it "rejects a nested attribute without an allowed sub-attribute" do
      ["creator", "physical_container", "physical_container.volume", "creator.category"].each do |field_name|
        form = described_class.new(current_user: current_user, form_params: { field_name: field_name, old_value: "x", new_value: "y" })
        expect(form.valid?).to be(false), "expected #{field_name} to be invalid"
      end
    end

    it "requires new_value" do
      form = described_class.new(current_user: current_user, form_params: { field_name: "description", old_value: "x", new_value: "" })
      expect(form.valid?).to be false
      expect(form.errors[:new_value]).to be_present
    end
  end

  describe "#field_label" do
    it "is the human-readable label for the selected field" do
      form = described_class.new(current_user: current_user, form_params: { field_name: "rights_holder" })
      expect(form.field_label).to eq("Rights holder")
    end
  end

  describe "#cart_work_count" do
    it "counts current_user's Cart, not all Works" do
      current_user.works_in_cart << create(:work)
      create(:work) # not in cart

      form = described_class.new(current_user: current_user, form_params: { field_name: "description", old_value: "x", new_value: "y" })
      expect(form.cart_work_count).to eq(1)
    end
  end

  describe "#matching_works and #matching_work_count" do
    let!(:matching_work) { create(:work, description: "a widget") }
    let!(:non_matching_work) { create(:work, description: "nothing to see here") }

    before do
      current_user.works_in_cart << matching_work
      current_user.works_in_cart << non_matching_work
    end

    it "returns empty when invalid" do
      form = described_class.new(current_user: current_user, form_params: { field_name: "not_a_real_field", old_value: "widget", new_value: "gadget" })

      expect(form.matching_works.to_a).to eq([])
    end

    it "finds only works whose field exactly matches old_value" do
      form = described_class.new(current_user: current_user, form_params: { field_name: "description", old_value: "a widget", new_value: "a gadget" })

      expect(form.matching_works).to contain_exactly(matching_work)
      expect(form.matching_work_count).to eq(1)
    end

    it "does not match a Work whose field matches but isn't in current_user's Cart" do
      current_user.works_in_cart.delete(matching_work)

      form = described_class.new(current_user: current_user, form_params: { field_name: "description", old_value: "a widget", new_value: "a gadget" })

      expect(form.matching_works.to_a).to eq([])
    end

    it "matches one exact element of an array-of-strings field" do
      work = create(:work, medium: ["Celluloid", "Dye"])
      current_user.works_in_cart << work

      expect(described_class.new(current_user: current_user, form_params: { field_name: "medium", old_value: "Celluloid", new_value: "x" }).matching_works).to include(work)
      expect(described_class.new(current_user: current_user, form_params: { field_name: "medium", old_value: "Cellu", new_value: "x" }).matching_works).not_to include(work)
    end

    it "matches a nested-model field's exact sub-attribute value" do
      work = create(:work, creator: [Work::Creator.new(value: "Foo Bar", category: "author")])
      current_user.works_in_cart << work

      expect(described_class.new(current_user: current_user, form_params: { field_name: "creator.value", old_value: "Foo Bar", new_value: "x" }).matching_works).to include(work)
      # category isn't searched, only value
      expect(described_class.new(current_user: current_user, form_params: { field_name: "creator.value", old_value: "author", new_value: "x" }).matching_works).not_to include(work)
    end
  end

  describe "#replace!" do
    let!(:work) { create(:work, description: "a widget") }

    before do
      current_user.works_in_cart << work
    end

    it "replaces the value, saves, and enqueues reindexing" do
      form = described_class.new(current_user: current_user, form_params: { field_name: "description", old_value: "a widget", new_value: "a gadget" })

      expect {
        expect(form.replace!).to be true
      }.to have_enqueued_job(ReindexWorksJob).with([work.id])

      expect(work.reload.description).to eq("a gadget")
    end

    it "does nothing and returns false when invalid" do
      form = described_class.new(current_user: current_user, form_params: { field_name: "not_a_real_field", old_value: "a widget", new_value: "a gadget" })

      expect(form.replace!).to be false
      expect(work.reload.description).to eq("a widget")
    end

    it "does not touch a matching Work that isn't in current_user's Cart" do
      current_user.works_in_cart.delete(work)

      form = described_class.new(current_user: current_user, form_params: { field_name: "description", old_value: "a widget", new_value: "a gadget" })

      expect(form.replace!).to be true # no matching works in cart, so "succeeds" trivially
      expect(work.reload.description).to eq("a widget")
    end

    it "replaces only the exactly-matching element of an array-of-strings field" do
      work.update!(medium: ["Celluloid", "Dye"])
      form = described_class.new(current_user: current_user, form_params: { field_name: "medium", old_value: "Celluloid", new_value: "Glass" })

      expect(form.replace!).to be true
      expect(work.reload.medium).to eq(["Glass", "Dye"])
    end

    it "replaces box or folder on the single nested physical_container, leaving its other sub-attributes alone" do
      work.update!(physical_container: Work::PhysicalContainer.new(box: "12", folder: "3"))

      expect(described_class.new(current_user: current_user, form_params: { field_name: "physical_container.box", old_value: "3", new_value: "x" }).matching_works).to be_empty

      form = described_class.new(current_user: current_user, form_params: { field_name: "physical_container.box", old_value: "12", new_value: "13" })
      expect(form.replace!).to be true
      expect(work.reload.physical_container.box).to eq("13")
      expect(work.physical_container.folder).to eq("3")

      form = described_class.new(current_user: current_user, form_params: { field_name: "physical_container.folder", old_value: "3", new_value: "4" })
      expect(form.replace!).to be true
      expect(work.reload.physical_container.attributes).to include("box" => "13", "folder" => "4")
    end

    it "replaces a controlled-list value in an array field without leaving duplicates" do
      work.update!(genre: ["Prints", "Engravings"])
      form = described_class.new(current_user: current_user, form_params: { field_name: "genre", old_value: "Engravings", new_value: "Prints" })

      expect(form.replace!).to be true
      expect(work.reload.genre).to eq(["Prints"])
    end

    it "replaces a scalar controlled-list value" do
      work.update!(rights: "http://rightsstatements.org/vocab/NoC-US/1.0/")
      new_rights = "http://creativecommons.org/publicdomain/mark/1.0/"
      form = described_class.new(current_user: current_user, form_params: { field_name: "rights", old_value: work.rights, new_value: new_rights })

      expect(form.replace!).to be true
      expect(work.reload.rights).to eq(new_rights)
    end

    it "replaces only the sub-attribute of a matching element of a nested-model field" do
      work.update!(creator: [
        Work::Creator.new(value: "Foo Bar", category: "author"),
        Work::Creator.new(value: "Someone Else", category: "photographer")
      ])
      form = described_class.new(current_user: current_user, form_params: { field_name: "creator.value", old_value: "Foo Bar", new_value: "New Name" })

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
      form = described_class.new(current_user: current_user, form_params: { field_name: "creator.value", old_value: "Foo Bar", new_value: "New Name" })

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
        form = described_class.new(current_user: current_user, form_params: { field_name: "file_creator", old_value: "Center for Oral History", new_value: "not-a-valid-file-creator" })

        expect(form.replace!).to be false
        expect(form.errors[:base]).to be_present
        expect(work.reload.file_creator).to eq("Center for Oral History")
      end
    end
  end
end
