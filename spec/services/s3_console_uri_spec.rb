require 'rails_helper'
require 'shrine/storage/memory'

describe S3ConsoleUri do
  describe "with components" do
    it "can generate" do
      url = S3ConsoleUri.new(bucket: "bucket-name", keypath: "path/to/file.jpg").console_uri
      expect(url).to eq(
        "https://s3.console.aws.amazon.com/s3/buckets/bucket-name?region=us-east-1&prefix=path/to/&prefixSearch=file.jpg"
      )
    end
  end

  describe "with S3 URL" do
    let(:s3_url) {
      "s3://bucket-name/asset/a6d8294d-3e95-49a6/307faecd.mp4"
    }
    it "can generate" do
      url = S3ConsoleUri.from_uri(s3_url).console_uri
      expect(url).to eq(
        "https://s3.console.aws.amazon.com/s3/buckets/bucket-name?region=us-east-1&prefix=asset/a6d8294d-3e95-49a6/&prefixSearch=307faecd.mp4"
      )
    end
  end

  describe "with http url with bucket name" do
    let(:https_url) { "https://bucket-name.s3.amazonaws.com/asset/a6d8294d-3e95-49a6/307faecd.mp4" }
    it "can generate" do
      url = S3ConsoleUri.from_uri(https_url).console_uri
      expect(url).to eq(
        "https://s3.console.aws.amazon.com/s3/buckets/bucket-name?region=us-east-1&prefix=asset/a6d8294d-3e95-49a6/&prefixSearch=307faecd.mp4"
      )
    end
  end

  describe "with shrine uploaded file" do
    around do |example|
      Shrine.storages[:test_s3_storage] = Shrine::Storage::S3.new(
        bucket: "test-bucket", region: "us-east-1",
        access_key_id: "fake", secret_access_key: "fake")
      Shrine.storages[:test_non_s3_storage] = Shrine::Storage::Memory.new

      example.run

      Shrine.storages.delete(:test_s3_storage)
      Shrine.storages.delete(:test_non_s3_storage)
    end

    it "can generate with an S3 storage" do
      url = S3ConsoleUri.from_shrine_uploaded_file(
        Shrine.uploaded_file(storage: :test_s3_storage, id: "path/to/file.jpg")
      ).console_uri

      expect(url).to start_with "https://s3.console.aws.amazon.com/s3/buckets/test-bucket"
    end

    it "will be nil with a non-S3 storage" do
      url = S3ConsoleUri.from_shrine_uploaded_file(
        Shrine.uploaded_file(storage: :test_non_s3_storage, id: "path/to/file.jpg")
      ).console_uri

      expect(url).to be_nil
    end
  end

  describe "bad uris with no identifiable bucket name" do
    [
      "/just/a/path.jpg",
      "https://nots3.com/path/file.jpg",
      "not a uri"
    ].each do |uri|
      it "cannot generate for #{uri}" do
        obj = S3ConsoleUri.from_uri(uri)

        expect(obj.has_console_uri?).to be false
        expect(obj.console_uri).to eq(nil)
      end
    end
  end
end
