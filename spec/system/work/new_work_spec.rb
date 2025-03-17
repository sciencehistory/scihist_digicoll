require 'rails_helper'
require 'pp'

RSpec.describe "New Work form", logged_in_user: :editor, type: :system, js: true do

  # stub out our FAST and Getty qa-based autocomplete to return 0-result responses,
  # using WebMock methods, so we aren't making HTTP requests in test, which we prohibit.
  # We aren't actually testing the qa autocomplete here.
  before do
    stub_request(:get, %r{\Ahttps?://fast.oclc.org}).to_return(
      status: 200,
      body: {response: { docs: [] }}.to_json,
      headers: {}
    )

    stub_request(:get, %r{\Ahttps?://vocab\.getty\.edu/sparql\.json\?}).to_return(
      status: 200,
      body: {results: { bindings: [] }}.to_json,
      headers: {}
    )
  end

  # As of Chrome/chromedriver 74.0, chromedriver will refuse to click on something
  # if it's covered up by something with "position: sticky", even if scrolling
  # could uncover it. Chromedriver will normally scroll to reveal something to click
  # on it. I think this is probably a chromedriver bug, but don't know how/where
  # to report it. For now, this is a workaround, we put this in just where
  # needed to get test to pass, which can change if page layout changes. :(
  def scrollToTop
    page.execute_script "window.scrollTo(0,0)"
  end

  let!(:collection) { FactoryBot.create(:collection) }
  let!(:work) { FactoryBot.create(:work, :with_complete_metadata) }

  scenario "save, edit, and re-save new work" do
    visit new_admin_work_path
    # Single-value free text
    %w(title description digitization_funder rights_holder).each do |p|
      fill_in "work[#{p}]", with: work.send(p)
    end

    # Multi-value free text
    %w(additional_title language medium subject).each do |p|
      attr_name = Work.human_attribute_name(p)
      all_items = work.send(p)
      all_items.length.times do |i|
        click_link("Add another #{attr_name}") unless i == 0
        all("fieldset.work_#{p} input[type=text]", minimum: i + 1)[i].
          fill_in with: all_items[i]
      end
    end

    # Multi-value free text in TEXTAREA
    %w(admin_note).each do |p|
      attr_name = Work.human_attribute_name(p)
      all_items = work.send(p)
      all_items.length.times do |i|
        click_link("Add another #{attr_name}") unless i == 0
        all("fieldset.work_#{p} textarea", minimum: i + 1)[i].
          fill_in with: all_items[i]
      end
    end



    # Multi-value free text (2)
    %w(extent series_arrangement).each do |p|
      attr_name = Work.human_attribute_name(p)
      all_items = work.send(p)
      all_items.length.times do |i|
        scrollToTop

        click_link("Add another #{attr_name}")
        all("fieldset.work_#{p} input[type=text]", minimum: i + 1)[i].fill_in with: all_items[i]
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
        all("fieldset.work_#{p} select", minimum: i + 1)[i].
          find("option[value='#{cat}']").select_option
        all("fieldset.work_#{p} input[type=text]", minimum: i + 1)[i].
          fill_in with: val
      end
    end

    #Multi-value dropdown:
    %w(genre).each do |p|
      all_items = work.send(p)
      all_items.length.times do |i|
        click_link("Add another #{attr_name}") unless i == 0
        val = work.send(p)[i]
        all("fieldset.work_#{p} select", minimum: i + 1)[i].
          find("option[value='#{val}']").
          select_option
      end
    end

    #Custom single-value selects:
    %w(file_creator department rights).each do |p|
      val = work.send(p)
      find("div.work_#{p} select option[value='#{val}']").select_option
    end

    # Dates:
    %w(date_of_work).each do |property|
      attr_name = Work.human_attribute_name(property)
      all_items = work.send(property)
      all_items.length.times do |i|
        click_link("Add another #{attr_name}") unless i == 0
        %w(start note finish).each do |p|
          all("fieldset.work_#{property} input[type=text][name*=#{p}]", minimum: i + 1)[i].
            fill_in with: all_items[i].attributes[p]
        end
        %w(start_qualifier finish_qualifier).each do |p|
          val = all_items[i].attributes[p]
          all("fieldset.work_#{property} select[name*=#{p}]", minimum: i + 1)[i].
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
          all("fieldset.work_#{property} input[type=text][name*=#{p}]", minimum: i + 1)[i].
            fill_in with: all_items[i].attributes[p]
        end
      end
    end

    #Related links
    all_items = work.related_link
    all_items.length.times do |i|
      click_link("Add another Related link")

      all("fieldset.work_related_link select[name*=category]", minimum: i + 1)[i].find("option[value=#{all_items[i].category}").select_option
      all("fieldset.work_related_link input[type=url][name*=url]", minimum: i + 1)[i].fill_in with: all_items[i].url
      all("fieldset.work_related_link input[type=text][name*=label]", minimum: i + 1)[i].fill_in with: all_items[i].label
    end

    # Physical container:
    %w(box volume page folder part shelfmark reel).each do |p|
      fill_in "work[physical_container_attributes][#{p}]",
        with: work.physical_container.attributes[p]
    end

    #Format
    scrollToTop
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
          all("fieldset.work_#{property} select[name*=#{p}]", minimum: i + 1)[i].
            find("option[value='#{val}']").select_option
        end
      end
    end

    # Collection, try to select reliably from tom-select
    within find("div.work_contained_by") do
      find('div.select').click
      find('input').fill_in with: "#{collection.title}\n"
    end
    # make sure selection has happened in hidden select field before we move on
    expect(page).to have_field("work[contained_by_ids][]",  multiple: true, visible: :all) do |select_tag|
      # not sure why we had ot do this in a custom block, using `with` arg wasn' working for multiple
      # value select.
      select_tag.value == [ collection.id ]
    end

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
      rights_holder subject title related_link
    ).each do |prop|
      expect(newly_added_work.send(prop)).to eq work.send(prop)
    end

    #newly_added_work.reload
    expect(newly_added_work.contained_by.to_a).to include(collection)
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
