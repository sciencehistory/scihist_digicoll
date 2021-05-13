require 'rails_helper'

# An attempt to test bundle exec rake scihist:orphans:report:derivatives .
describe OrphanS3Derivatives do
  before do
    fake_aws_s3_client.stub_responses(:list_objects_v2,
        Aws::S3::Types::ListObjectsOutput.new(
        is_truncated: false,   marker: '',
        next_marker: nil,      name: 's3.bucket',
        delimiter: '/',        max_keys: 1000,
        encoding_type: 'url',
        contents: s3_contents,
        common_prefixes: []
      )
    )
    allow_any_instance_of(S3PathIterator).to receive(:s3_client).and_return(fake_aws_s3_client)
    allow_any_instance_of(S3PathIterator).to receive(:s3_bucket_name).and_return('s3.bucket')
  end

  let(:fake_aws_s3_client) { Aws::S3::Client.new(stub_responses: true) }

  let(:id_1) { "0001d800-482d-4dcf-80b7-84f273580a13" }
  let(:id_2) { "00042a06-7216-4ece-a57c-670e4e9b5c46" }

  let(:file_paths) do
    [
      "#{id_1}/download_full/download_full.jpg",
      "#{id_1}/download_large/download_large.jpg",
      "#{id_1}/download_medium/download_medium.jpg",
      "#{id_1}/download_small/download_small.jpg",
      "#{id_2}/download_full/download_full.jpg",
      "#{id_2}/download_large/download_large.jpg",
      "#{id_2}/download_medium/download_medium.jpg",
      "#{id_2}/download_small/download_small.jpg"
    ]
  end

  let(:s3_contents) do
    file_paths.map{|path| Struct.new(:key).new(path)}
  end

  let!(:work) do
    create(:public_work,
      members: [
        create(:asset_with_faked_file, id: id_1,
          faked_derivatives: {
             "download_full"   => create(:stored_uploaded_file, id: "#{id_1}/download_full/download_full.jpg"),
             "download_large"  => create(:stored_uploaded_file, id: "#{id_1}/download_large/download_large.jpg"),
             "download_medium" => create(:stored_uploaded_file, id: "#{id_1}/download_medium/download_medium.jpg"),
             "download_small"  => create(:stored_uploaded_file, id: "#{id_1}/download_small/download_small.jpg")
           }
        ),
        create(:asset_with_faked_file, id: id_2,
          faked_derivatives: {
             "download_full"   => create(:stored_uploaded_file, id: "#{id_2}/download_full/download_full.jpg"),
             "download_large"  => create(:stored_uploaded_file, id: "#{id_2}/download_large/download_large.jpg"),
             "download_medium" => create(:stored_uploaded_file, id: "#{id_2}/download_medium/download_medium.jpg"),
             "download_small"  => create(:stored_uploaded_file, id: "#{id_2}/download_small/download_small.jpg"),
          }
        )
      ]
    )
  end

  let (:orphan_checker) do
    OrphanS3Derivatives.new(show_progress_bar: false)
  end

  it "normal situation does not create a problem" do
    orphan_checker.report_orphans
  end
end