require 'rails_helper'
require 'pp'

RSpec.feature "New Work form", js: true do
  let!(:collection) { FactoryBot.create(:collection) }
  let!(:work) { FactoryBot.create(:work, :with_complete_metadata) }

  scenario "save, edit, and re-save new work" do
    visit new_admin_work_path

    # Single-value free text
    %w(title description source admin_note rights_holder).each do |p|
      fill_in "work[#{p}]", with: work.send(p)
    end

    # Multi-value free text
    %w(additional_title language medium subject).each do |p|
      attr_name = Work.human_attribute_name(p)
      all_items = work.send(p)
      all_items.length.times do |i|
        click_link("Add another #{attr_name}") unless i == 0
        all("fieldset.work_#{p} input[type=text]")[i].
          fill_in with: all_items[i]
      end
    end

    # Multi-value free text (2)
    %w(extent series_arrangement related_url).each do |p|
      attr_name = Work.human_attribute_name(p)
      all_items = work.send(p)
      all_items.length.times do |i|
        click_link("Add another #{attr_name}")
        all("fieldset.work_#{p} input[type=text]")[i].fill_in with: all_items[i]
      end
    end

    # Multi-value free text with associated category dropdown
    %w(creator place external_id).each do |p|
      attr_name = Work.human_attribute_name(p)
      all_items = work.send(p)
      all_items.length.times do |i|
        val =  all_items[i].value
        cat =  all_items[i].category
        click_link("Add another #{attr_name}") unless i == 0
        all("fieldset.work_#{p} select")[i].
          find("option[value='#{cat}']").select_option
        all("fieldset.work_#{p} input[type=text]")[i].
          fill_in with: val
      end
    end

    #Multi-value dropdown:
    %w(genre).each do |p|
      all_items = work.send(p)
      all_items.length.times do |i|
        click_link("Add another #{attr_name}") unless i == 0
        val = work.send(p)[i]
        all("fieldset.work_#{p} select")[i].
          find("option[value='#{val}']").
          select_option
      end
    end

    #Custom single-value selects:
    %w(file_creator department rights).each do |p|
      val = work.send(p)
      find("div.work_#{p} select option[value='#{val}']").select_option
    end

    #Custom single-value selects (2)
    %w(exhibition).each do |p|
      attr_name = Work.human_attribute_name(p)
      all_items = work.send(p)
      all_items.length.times do |i|
        click_link("Add another #{attr_name}")
        val = all_items[i]
        all("fieldset.work_#{p} select")[i].
          find("option[value='#{val}']").select_option
      end
    end

    # Dates:
    %w(date_of_work).each do |property|
      attr_name = Work.human_attribute_name(property)
      all_items = work.send(property)
      all_items.length.times do |i|
        click_link("Add another #{attr_name}") unless i == 0
        %w(start note finish).each do |p|
          all("fieldset.work_#{property} input[type=text][name*=#{p}]")[i].
            fill_in with: all_items[i].attributes[p]
        end
        %w(start_qualifier finish_qualifier).each do |p|
          val = all_items[i].attributes[p]
          all("fieldset.work_#{property} select[name*=#{p}]")[i].
            find("option[value='#{val}']").select_option
        end
      end
    end

    #Inscriptions
    %w(inscription).each do |property|
      attr_name = Work.human_attribute_name(property)
      all_items = work.send(property)
      all_items.length.times do |i|
        click_link("Add another #{attr_name}")
        %w(location text).each do |p|
          all("fieldset.work_#{property} input[type=text][name*=#{p}]")[i].
            fill_in with: all_items[i].attributes[p]
        end
      end
    end

    # Physical container:
    %w(box volume page folder part shelfmark).each do |p|
      fill_in "work[physical_container_attributes][#{p}]",
        with: work.physical_container.attributes[p]
    end

    #Format
    work.format.each do |val|
      find("input[value=#{val}]").check
    end

    #Additional Credit
    %w(additional_credit).each do |property|
      attr_name = Work.human_attribute_name(property)
      all_items = work.send(property)
      all_items.length.times do |i|
        click_link("Add another #{attr_name}")
        %w(role name).each do |p|
          val = all_items[i].attributes[p]
          all("fieldset.work_#{property} select[name*=#{p}]")[i].
            find("option[value='#{val}']").select_option
        end
      end
    end

    # Collection membership
    find("#work_contained_by_ids option[value='#{collection.id}']").select_option

    click_button "Create Work"

    # check page, before checking data, to make sure action has completed.
    expect(page).to have_css("h1", text: "Add Files").and have_text("To: #{work.title}")

    # check data
    newly_added_work = Work.order(:created_at).last

    %w(
      additional_credit additional_title admin_note creator
      department date_of_work description external_id format
      file_creator genre inscription language medium
      physical_container place rights
      rights_holder source subject title
    ).each do |prop|
      expect(newly_added_work.send(prop)).to eq work.send(prop)
    end

    expect(newly_added_work.contained_by).to include(collection)
  end

  context "creating a child work" do
    let(:parent_work) { FactoryBot.create(:work, :with_collection, :with_assets, title: "parent_work") }

    it "creates with proper inherited metadata" do
      members_max_position = parent_work.members.maximum(:position)

      visit new_admin_work_path(parent_id: parent_work.friendlier_id)

      fill_in "work[title]", with: "child work"

      find("#work_external_id_attributes_0_category option[value=object]").select_option
      fill_in "work_external_id_attributes_0_value", with: "some_object_id"

      click_button "Create Work"

      # check page, before checking data, to make sure action has completed.
      expect(page).to have_css("h1", text: "Add Files").and have_text("To: child work")

      # check data
      added_work = Work.order(:created_at).last

      expect(added_work.title).to eq("child work")
      expect(added_work.parent_id).to eq(parent_work.id)
      expect(added_work.contained_by).to eq(parent_work.contained_by)
      expect(added_work.position).to eq(members_max_position + 1)
    end
  end
end
