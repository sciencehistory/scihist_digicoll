require 'rails_helper'
#
# This is an API external partners may be depending upon, so we should try to
# keep existing specs passing as much as we can,  although if our internal,
# structures change TOO much we may not be able to. We aren't at present
# able to actually make guarantees here, we aren't a vendor.
#
describe WorkJsonSerializer, type: :model, queue_adapter: :inline do
  let(:work) { create(:work, :published, :with_complete_metadata) }

  # symbolize keys for convenience in our tests, they used to be symbols in Alba 1.0
  # https://github.com/okuramasafumi/alba/blob/main/CHANGELOG.md#200-2022-10-21
  let(:serializable_hash) { WorkJsonSerializer.new(work).serializable_hash.deep_symbolize_keys }

  # just a 'macro' to for common tests on a key expecte to have an array of hashes
  # having certain keys.
  def expect_to_many_shape(hash, attribute, keys:)
    expect(hash[attribute]).to be_kind_of(Array)
    hash[attribute].each do |sub_hash|
      expect(sub_hash).to be_kind_of(Hash)
      expect(sub_hash.keys).to include(*keys)
    end
  end

  # Not exhaustively testing every value, but trying to mostly get the shape
  it "serializes" do
    expect(serializable_hash).to be_kind_of(Hash)

    expect(serializable_hash[:id]).to eq work.friendlier_id
    expect(serializable_hash[:internal_id]).to eq work.id
    expect(serializable_hash[:title]).to eq work.title

    expect(serializable_hash[:links][:img_thumbnail]).to be_present
    expect(serializable_hash[:links][:html_self]).to be_present
    expect(serializable_hash[:links][:html_self]).to include(work.friendlier_id)

    expect(serializable_hash[:description]).to eq work.description
    expect(serializable_hash[:description_html]).to eq DescriptionDisplayFormatter.new(work.description).format

    expect(serializable_hash[:published_at]).to eq work.published_at.utc.iso8601
    expect(serializable_hash[:updated_at]).to eq work.updated_at.utc.iso8601

    expect(serializable_hash[:physical_container].keys).to include(:box, :folder, :volume, :part, :page, :shelfmark, :formatted, :reel)


    # Some to_many's, arrays of hashes, we just test that they exist and the sub-hashes
    # include expected keys.
    expect_to_many_shape(serializable_hash, :creator, keys: [:category, :value])
    expect_to_many_shape(serializable_hash, :place, keys: [:category, :value])
    expect_to_many_shape(serializable_hash, :date_of_work, keys: [:start, :start_qualifier, :finish, :finish_qualifier, :note, :formatted])
    expect_to_many_shape(serializable_hash, :inscription, keys: [:location, :text])
    expect_to_many_shape(serializable_hash, :related_link, keys: [:url, :category, :label])
    expect_to_many_shape(serializable_hash, :additional_credit, keys: [:role, :name])
  end

  it "includes all attr_json unless specifically excluded" do
    # all attr_json except ones we've deny-listed as not wanting to serialize at present.
    expected_attributes = Work.attr_json_registry.attribute_names.excluding(:external_id, :admin_note, :ocr_requested)

    expected_attributes.each do |attr_name|
      if work.send(attr_name).present?
        expect(serializable_hash[attr_name.to_sym]).to be_present, "expected #{attr_name} to be serialized"
      end
    end
  end

  describe "for Oral History" do
    let(:work) { create(:oral_history_work, :public_files, published: true) }

    it "includes interviewer profile" do
      expect(serializable_hash[:interviewer_profile]).to eq (work.oral_history_content.interviewer_profiles.collect do |profile|
        { name: profile.name,
          profile: profile.profile
        }
      end)
    end

    it "includes interviewee biography" do
      expect(serializable_hash[:interviewee_biography]).to be_kind_of(Array)

      # this is kind of a pain to check in detail, we just establish the basic shape
      serializable_hash[:interviewee_biography].each do |bio_hash|
        expect(bio_hash[:name]).to be_present
        expect(bio_hash[:birth].keys).to include(:date, :city, :state, :province, :country)
        expect(bio_hash[:death].keys).to include(:date, :city, :state, :province, :country)

        expect_to_many_shape(bio_hash, :education, keys: [:date, :institution, :degree, :discipline])
        expect_to_many_shape(bio_hash, :job, keys: [:institution, :role, :start_date, :end_date])
        expect_to_many_shape(bio_hash, :honor, keys: [:honor, :start_date, :end_date])
      end
    end

    it "includes oral_history_assets" do
      transcript_asset = work.members.find { |m| m.role == "transcript" }

      expect(serializable_hash[:oral_history_assets]).to be_present
      expect(serializable_hash[:oral_history_assets]).to eq([
        {
          id: transcript_asset.friendlier_id,
          role: "transcript",
          content_type: transcript_asset.content_type,
          original_filename: transcript_asset.original_filename,
          url: Rails.application.routes.url_helpers.download_url(transcript_asset.file_category, transcript_asset, host: ScihistDigicoll::Env.lookup(:app_url_base))
        }
      ])
    end

    describe "work with by-request assets" do
      let(:work) { create(:oral_history_work, :available_by_request) }

      it "does not include URLs to non-public files" do
        front_matter_asset = work.members.find { |m| m.role == "front_matter" }

        expect(serializable_hash[:oral_history_assets]).to be_present
        expect(serializable_hash[:oral_history_assets].select { |hash| hash[:role] == "transcript" }).to be_empty

        expect(serializable_hash[:oral_history_assets]).to eq([
          {
            id: front_matter_asset.friendlier_id,
            role: "front_matter",
            content_type: front_matter_asset.content_type,
            original_filename: front_matter_asset.original_filename,
            url: Rails.application.routes.url_helpers.download_url(front_matter_asset.file_category, front_matter_asset, host: ScihistDigicoll::Env.lookup(:app_url_base))
          }
        ])
      end
    end
  end
end
