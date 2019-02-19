require 'rails_helper'

# We're not gonna test every possible thing here, but a few
RSpec.describe "Edit work metadata form", :logged_in_user, type: :system, js: true do
  let!(:new_collection) { FactoryBot.create(:collection) }
  let(:work) { FactoryBot.create(:work, :with_complete_metadata, :with_collection, :with_assets, asset_count: 3) }

  # only gonna edit the tricky stuff for now
  it "edits work" do
    visit edit_admin_work_path(work)

    # Set collection to a new thing, unselect old thing
    original_collection = work.contained_by.first
    find("#work_contained_by_ids option[value='#{original_collection.id}']").unselect_option
    find("#work_contained_by_ids option[value='#{new_collection.id}']").select_option

    # Set representative to a new thing
    new_representative = work.members.find {|m| m.id != work.representative_id}
    find("#work_representative_id option[value='#{new_representative.id}']").select_option

    click_button "Update Work"

    # check page, before checking data, to make sure action has completed.
    expect(page).to have_css("h1", text: work.title)

    # check data
    work.reload

    expect(work.representative_id).to eq(new_representative.id)
    expect(work.contained_by_ids).to include(new_collection.id)
    expect(work.contained_by_ids).not_to include(original_collection.id)
  end

  it "sanitizes description" do
    visit edit_admin_work_path(work)

    fill_in "work[description]", with: <<~EOS
        <script>evil</script>
        <p>This is a paragraph</p>
        This is a line with <b>bold</b>, <i>italic</i>, <cite>cite</cite>, and a <a href='http://example.com' onclick='foo'>link</a>.

        This is a final line
    EOS

    click_button "Update Work"

    # check page, before checking data, to make sure action has completed.
    expect(page).to have_css("h1", text: work.title)
    work.reload

    expect(work.description).to eq(<<~EOS)
        evil
        This is a paragraph
        This is a line with <b>bold</b>, <i>italic</i>, <cite>cite</cite>, and a <a href=\"http://example.com\">link</a>.

        This is a final line
    EOS
  end
end
