require 'rails_helper'

RSpec.describe "Convert asset to child work", logged_in_user: :editor, type: :system, js: true do
  let(:work) { FactoryBot.create(:work, :with_complete_metadata, :with_collection, :with_assets, asset_count: 5) }
  let(:conversion_source) { work.members[2] }

  it "converts" do
    work.update(representative_id: conversion_source.id)

    original_position = conversion_source.position
    visit admin_asset_path(conversion_source)

    expect do
      click_on "Convert to child work"
      expect(page).to have_current_path(%r{\A/admin/works})
      expect(page).to have_content("Asset promoted to child work")
    end.to change { Work.count }.by(1).and change { Asset.count }.by(0)

    work.reload
    expect(conversion_source.reload.persisted?).to be(true)
    new_work = Work.order(:created_at).last

    expect(new_work.title).to eq(work.title)
    expect(new_work.parent).to eq(work)
    expect(new_work.contained_by).to eq(work.contained_by)
    expect(new_work.position).to eq(original_position)
    expect(work.representative_id).to eq(new_work.id)

    # all attr_json attributes
    expect(new_work.json_attributes).to eq(work.json_attributes)
  end

end
