require 'rails_helper'

require 'spec_helper'
require 'scihist_digicoll/shrine_storage/cloudfront_s3_storage'

# We're not gonna test everything and make sure it's good as a storage, we just
# assume our light sub-class is doing what it's superclass is doing. Famous last words,
# but it gets very complicated to test otherwise.
#
RSpec.describe ScihistDigicoll::ShrineStorage::CloudfrontS3Storage do
  let(:cloudfront_host) { "fakefakefake.cloudfront.net"}
  let(:bucket_name) { "my-bucket" }
  let(:object_key) { "some/directory/file.jpg" }
  let(:region) { "us-east-1"}

  let(:default_storage_params) do
    {
      host: cloudfront_host,
      bucket: bucket_name,
      region: region,
      access_key_id:     "faked",
      secret_access_key: "faked",
    }
  end

  describe "unrestricted public distribution" do
    let(:storage) do
      ScihistDigicoll::ShrineStorage::CloudfrontS3Storage.new(
        **default_storage_params.merge(public: true)
      )
    end

    it "produces good url" do
      expect(storage.url(object_key)).to eq("https://#{cloudfront_host}/#{object_key}")
    end

    it "includes allow-listed query params" do
      expect(
        storage.url(object_key, response_content_disposition: "attachment", response_content_type: "application/x-test")
      ).to eq("https://#{cloudfront_host}/#{object_key}?response-content-disposition=attachment&response-content-type=application%2Fx-test")
    end

    it "strips unrecognized param options" do
      expect(
        storage.url(object_key, foo: "bar", baz: "bum")
      ).to eq("https://#{cloudfront_host}/#{object_key}")
    end


    describe "with shrine prefix" do
      let(:prefix) { "foo/bar" }
      let(:storage) do
        ScihistDigicoll::ShrineStorage::CloudfrontS3Storage.new(
          **default_storage_params.merge(public: true, prefix: prefix)
        )

      end

      it "produces urls with prefix" do
        expect(storage.url(object_key, public: true)).to eq("https://#{cloudfront_host}/#{prefix}/#{object_key}")
      end
    end
  end

  describe "restricted distribution" do
    let(:cloudfront_key_pair_id) { "fakeExampleAccessKeyId"}
    let(:cloudfront_private_key) { File.read(Rails.root + "spec/test_support/demo_private_key.pem") }

    let(:storage) do
      ScihistDigicoll::ShrineStorage::CloudfrontS3Storage.new(
        **default_storage_params.merge(
          public: false,
          cloudfront_key_pair_id: cloudfront_key_pair_id,
          cloudfront_private_key: cloudfront_private_key
        )
      )
    end

    it "produces signed and expiring url" do
      generated = storage.url(object_key)
      expect(generated).to be_present

      parsed = URI.parse(generated)

      expect(parsed.host).to eq cloudfront_host
      expect(parsed.path).to eq "/#{object_key}"

      query = Rack::Utils.parse_query(parsed.query)

      expires = query["Expires"]
      expect(expires).to be_present
      expect(expires.to_i).to be_within(2.minutes).of(Time.now.utc.to_i + 1.day.to_i)

      expect(query["Key-Pair-Id"]).to eq cloudfront_key_pair_id
      expect(query["Signature"]).to be_present

      expect(generated).to eq storage.cloudfront_signer.signed_url("https://#{cloudfront_host}/#{object_key}", expires: expires.to_i)
    end

    it "can include allow-listed params" do
      generated = storage.url(object_key, response_content_disposition: "attachment", response_content_type: "application/x-test")
      expect(generated).to be_present

      parsed = URI.parse(generated)
      query = Rack::Utils.parse_query(parsed.query)
      expect(query["Expires"]).to be_present
      expect(query["Key-Pair-Id"]).to eq cloudfront_key_pair_id
      expect(query["Signature"]).to be_present

      expect(query["response-content-disposition"]).to eq "attachment"
      expect(query["response-content-type"]).to eq "application/x-test"
    end
  end
end
