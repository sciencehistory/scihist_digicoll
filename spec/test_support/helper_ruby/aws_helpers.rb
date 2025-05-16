module AwsHelpers
  # To test our orphan checking code,
  # we need to be able to feed the
  # checker an array of fake s3 paths.
  #
  # This helper allows you to do something like:
  #
  #     paths = ['fake/path/1.jpg', 'fake/path/2.jpg']
  #     allow(orphan_checker.s3_iterator).to receive(:s3_client).
  #       and_return(AwsHelpers::MockAwsClient.new(paths: paths).client)
  #
  class MockS3Client
    attr_reader :client
    def initialize(paths:, bucket_name:"bucket", common_prefixes: [])
      contents = paths.map { |path| Aws::S3::Types::Object.new(key: path) }

      output = Aws::S3::Types::ListObjectsV2Output.new(
        name: bucket_name,
        common_prefixes: common_prefixes,
        contents: contents,
        is_truncated: false,
        delimiter: '/',
        max_keys: 1000,
        encoding_type: 'url',
      )

      @client = Aws::S3::Client.new(stub_responses: true)
      @client.stub_responses( :list_objects_v2, output)
    end
  end
end
