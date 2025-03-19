require 'rails_helper'

describe "Oral history work", logged_in_user: :editor, queue_adapter: :test do
  let(:work) { FactoryBot.create(:oral_history_work) }

  describe "combined audio derivatives" do
    before do
      visit admin_work_path(work)
      click_on "Oral History"
    end

    describe "with no public audio sources" do
      it "says can't create" do
        expect(page).to have_text("This oral history doesn't have any published audio segments associated with it, so has no combined audio derivatives.")
        expect(page).not_to have_css("a", text: /Generate combined audio derivatives/)
      end
    end

    describe "with audio assets without combined derivative" do
      let(:work) { FactoryBot.create(:work, :with_complete_metadata, genre: ["Oral histories"], members: [create(:asset_with_faked_file, :mp3, published: true)]) }

      it "says no up to date combined derivative, can create one" do
        expect(page).to have_text("This oral history does not have up to date combined audio derivatives for the 1 published audio segment")
        expect(page).to have_css("a", text: /Generate combined audio derivatives/)

        click_on "Generate combined audio derivatives"
        expect(page).to have_text("audio derivative job has been added ")

        expect(CreateCombinedAudioDerivativesJob).to have_been_enqueued
        expect(page).to have_text("Attempting to create combined audio derivatives. Job status: queued")
      end
    end

    describe "with audio assets, out of date combined derivative" do
      let(:work) do
        FactoryBot.create(:work,
          :with_complete_metadata,
          genre: ["Oral histories"],
          members: [create(:asset_with_faked_file, :m4a, published: true)]
        ).tap do |work|
          work.oral_history_content!.update(combined_audio_fingerprint: "bad", combined_audio_m4a: StringIO.new("bad"))
        end
      end

      it "says no up to date combined derivative" do
        expect(page).to have_text("This oral history does not have up to date combined audio derivatives for the 1 published audio segment")
        expect(page).to have_css("a", text: /Generate combined audio derivatives/)
      end
    end

    describe "with audio assets, up to date combined derivative" do
      let(:work) do
        FactoryBot.create(:work,
          :with_complete_metadata,
          genre: ["Oral histories"],
          members: [create(:asset_with_faked_file, :m4a, published: true)]
        ).tap do |work|
          expected_fingerprint = CombinedAudioDerivativeCreator.new(work).fingerprint
          work.oral_history_content!.update(combined_audio_fingerprint: expected_fingerprint, combined_audio_m4a: StringIO.new("fake"))
        end
      end

      it "says up to date" do
        expect(page).to have_text("The combined audio derivatives, created from 1 published audio segments, are up to date")
      end
    end
  end
end
