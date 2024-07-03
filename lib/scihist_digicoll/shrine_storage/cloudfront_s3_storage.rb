require "shrine/storage/s3"
require 'faster_s3_url/shrine/storage'
require "aws-sdk-cloudfront"


# A shrine storage for use with AWS S3, and sub-classing Shrine's S3 storage -- but will generate
# access URLs assuming CloudFront CDN in front of S3, according to our conventions.
#
# A `host` is required on initialization -- the cloudfront distro hostname
# `public` is set on initialization, and can't be over-ridden in #url, if not public then CloudFront signing will be used
#
# Cloudfront key id and public key are generally supplied from Env.
#
# https://shrinerb.com/docs/storage/s3
#
# For the clodufront_key_pair_id and cloudfront_private_key, see https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-trusted-signers.html#private-content-creating-cloudfront-key-pairs
#
# For general write-up of how we've set things up, see https://bibwild.wordpress.com/2024/06/18/cloudfront-in-front-of-s3-using-response-content-disposition/
module ScihistDigicoll
  module ShrineStorage
    class CloudfrontS3Storage < ::Shrine::Storage::S3
      attr_reader :host, :public_mode, :cloudfront_signer, :key_pair_id

      QUERY_PARAMS_PROXIED = {
        response_cache_control: "response-cache-control",
        response_content_disposition: "response-content-disposition",
        response_content_encoding: "response-content-encoding",
        response_content_language: "response-content-langauge",
        response_content_type: "response-content-type"
      }.freeze

      DEFAULT_EXPIRES_IN = 1.day

      # generally any option tht Shrine::Storage::S3 respects can be used, and are passed through,
      # except `signer` is not supported and will error -- we always use CloudFront signing if public: false
      #
      # @param host [String] set only in initializer, the Cloudfront distro host
      #
      # @parma public [Boolean] (default true), if false, then Cloudfront signing will be done to urls, can not be
      #      over-ridden in #url, since the way we set up CloudFront distros they either require signing of all urls or none.
      #
      # @param cloudfront_key_pair_kid [String] required if public:false, the cloudfront_key_pair id used for signing
      #
      # @param cloudfront_private_key [String] required if public:false, RSA publikc key corresopnding to cloudfront_key_pair_id
      #
      # NOTE: You will still need keys `access_key_id:` and `secret_access_key:` (or otherwise have AWS credentials
      #       auto-discoverable), because bucket edit operations etc require them!
      #
      def initialize(host:, public: true, cloudfront_key_pair_id: nil, cloudfront_private_key: nil, **options)
        if options[:signer]
          raise ArgumentError.new("#{self.class.name} does not support :signer option of Shrine::Storage::S3.")
        end

        @public_mode = !!public
        @host = host

        @public_builder = FasterS3Url::Shrine::Storage.new(public: true, host: host, **options)

        if !public_mode
          @cloudfront_signer = Aws::CloudFront::UrlSigner.new(
             key_pair_id: (cloudfront_key_pair_id || raise(ArgumentError.new("option `cloudfront_key_pair_id:` is required when `public:` is false"))),
             private_key: (cloudfront_private_key || raise(ArgumentError.new("option `cloudfront_private_key:` is required when `public:` is false")))
          )
        end

        super(public: public_mode, **options)
      end

      # unlike base Shrine::Storage::S3, does not support `host` here, do it in
      # initializer instead.
      #
      # # We IGNORE `public` option here -- our Cloudfront is either public or does not support,
      # public, no way to change per-url. But we ignore rather than raise, to allow
      # swap-in compatibility with code expecting to send it for normal S3.
      #
      # Unlike Shrine::Storage::S3, recognized S3 options (AWS ruby SDK style)
      # *are* passed on in public mode too, becuase in some cases we have set
      # up cloudfront to proxy them.
      #
      # Otherwise, same options as Shrine::S3::Storage should be supported, please
      # see docs there. https://shrinerb.com/docs/storage/s3
      def url(id, **options)
        if options[:host]
          raise ArgumentError.new("#{self.class.name}#url does not support :host option of Shrine::Storage::S3. You can only set host in initializer")
        end

        if public_mode
          public_url(id, **options)
        else
          signed_url(id, **options)
        end
      end

      def public_url(key, **options)
        "#{@public_builder.url(key)}#{query_param_serialized(options)}"
      end

      def signed_url(key, expires_in: DEFAULT_EXPIRES_IN, **options)
        expires = options[:expires]&.to_i || (Time.now.utc.to_i + expires_in.to_i)

        cloudfront_signer.signed_url(public_url(key, **options),
          expires: expires,
          **options
        )
      end

      protected

      def query_param_serialized(options)
        return nil if options.blank?

        params = options.collect do |key, value|
          [QUERY_PARAMS_PROXIED[key], value] if QUERY_PARAMS_PROXIED.has_key?(key)
        end.compact

        return nil if params.blank?

        "?#{params.to_h.compact.to_param}"
      end
    end
  end
end
