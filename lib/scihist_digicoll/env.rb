require 'socket'
require "shrine/storage/file_system"
require "shrine/storage/s3"
require 'faster_s3_url/shrine/storage'
require 'scihist_digicoll/shrine_storage/cloudfront_s3_storage'


module ScihistDigicoll
  # Storing "environmental" infrastructure/context information.
  #
  # All keys defined here can be set in `./config/local_env.yml` with the key name as
  # defined here as a hash key. (This is how environmental context is current supplied in our
  # production deployments).
  #
  # OR they can be defined by shell ENV with an uppercase version of the name. For instance,
  # `define_key :aws_access_key_id` means you can supply the key as shell env `AWS_ACCESS_KEY_ID`.
  # If a key is set in shell env, it will take priority over a key set in `local_env.yml`
  #
  # In development, you can use a local local_env.yml or shell env or a combination, whatever is
  # most convenient. You can also use `./config/local_env_development.yml` to make sure keys
  # don't effect spec/test runs, with unexpected results. shell env or `local_env.yml` will effect
  # test runs too.
  #
  # Many keys have defaults, sometimes depending on Rails.env, and sometimes defined in terms of other
  # keys. Look at the code below to see what the keys are and what their defaults are.
  #
  # All keys set in ScihistDigicoll::Env are assumed to be immutable for life of the process, they
  # are environmental context, and can't be changed in the middle of the process. Once looked up,
  # they are fixed.
  #
  # We moved the supporting implementation for this setup into Kithe, so for more information on implementation,
  # see the Kithe code and documentation for the superclass.
  class Env < Kithe::ConfigBase
    # look for config/local_env.yml, and if we're NOT in production,
    # config/local_env_#{env}.yml

    rails_env = defined?(Rails) ? Rails.env.to_s : (ENV["RAILS_ENV"] || "development")
    if rails_env != "development" && rails_env != "test"
      self.config_file_paths = ["config/local_env.yml"]
    else
      self.config_file_paths = ["config/local_env.yml", "config/local_env_#{rails_env.downcase}.yml"]
    end

    # Set as a staging server in local_env.yml with `service_level: staging`?
    def self.staging?
      @staging ||= ("staging" == lookup(:service_level))
    end

    define_key :secret_key_base
    define_key :service_level, allows: ["staging", "production", nil]

    def self.staging?
      @staging ||= lookup(:service_level) == "staging"
    end

    def self.production?
      @production ||= lookup(:service_level) == "production"
    end

    define_key :rails_log_level, default: -> {
      # :info is one step less info than :debug, it's still a fairly large amount of info, including
      # all requests. We're trying this as default in production.
      #
      # For non-production environments, we don't by default override Rails default.
      :info if Rails.env.production?
    }, system_env_transform: ->(str) { str.to_sym }


    # what env for honeybadger to log, if not given we'll use the `service_level` value
    # (staging/production), or if that's not there either, just Rails.env (development, testing)
    define_key :honeybadger_env, default: -> {
      ScihistDigicoll::Env.lookup(:service_level) || Rails.env.to_s
    }


    # Rails-style db url, eg postgres://myuser:mypass@localhost/somedatabase
    define_key :rails_database_url, default: -> {
      # heroku supplies this as just DATABASE_URL, let's take that too
      ENV['DATABASE_URL']
    }

    # Credentials looked up using "standard" AWS auth (ie from ENV variables
    # or ~/.aws/ files etc), that initially we use in development mode
    # to lookup keys
    #
    # https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html
    def self.aws_credentials
      @aws_credentials ||= begin
        client = Aws::S3::Client.new
        credentials = client.config.credentials
        # not sure why we do this, but it gets us a type of AWS credentials
        # object that will actually have #access_key_id and #secret_access_key
        # methods
        credentials = credentials.credentials if credentials.respond_to?(:credentials)
      end
    end

    define_key :aws_access_key_id, default: ->{
      # default to looking things up via standard AWS, only in development
      self.class.aws_credentials.access_key_id if Rails.env.development?
    }
    define_key :aws_secret_access_key, default: ->{
      # default to looking things up via standard AWS, only in development
      self.class.aws_credentials.secret_access_key if Rails.env.development?
    }


    # MICROSOFT SINGLE SIGN ON / SSO / ENTRA / AZURE / OAUTH / OMNIAUTH
    # See also https://github.com/sciencehistory/scihist_digicoll/pull/2769
    # See also config/initializers/devise.rb
    # See also https://sciencehistory.atlassian.net/wiki/spaces/HDC/pages/1915748368/Heroku+Operational+Components+Overview#Microsoft-SSO
    # See also https://portal.azure.com/
    # See also 1Password (or equivalent password store).

    # This key switches Microsoft SSO (aka Entra, aka Azure) on or off.
    define_key :log_in_using_microsoft_sso, default: false, system_env_transform: Kithe::ConfigBase::BOOLEAN_TRANSFORM

    # "Tenant" or "Directory" is what Microsoft calls our Entra directory.
    # This will have the same value for *all* applications (digital collections or other)
    # that authenticate using Microsoft SSO.
    define_key :microsoft_sso_tenant_id

    # "Client" or "Application" is what Microsoft calls a website that uses Microsoft SSO.
    # This will have a different value for dev; staging; and production.
    define_key :microsoft_sso_client_id

    # This is effectively a password - a shared secret.
    define_key :microsoft_sso_client_secret

    # Official SHI google arts and culture project:
    define_key :google_arts_and_culture_project_id
    define_key :google_arts_and_culture_bucket_name
    define_key :google_arts_and_culture_credentials

    # Test Google project, just for testing uploads in this project
    define_key :test_google_project_credentials
    define_key :test_google_project_user_id

    # MediaConvert requires a special role to be passed to MediaConvert
    # jobs, that has access to input/output buckets, and MediaConvert itself.
    #
    # https://github.com/aws-samples/aws-media-services-simple-vod-workflow/blob/master/1-IAMandS3/README.md#1-create-an-iam-role-to-use-with-aws-elemental-mediaconvert
    #
    # prod/staging roles are probably scihist-digicoll-staging-MediaConvertRole etc,
    # but should be set in ENV.
    define_key :aws_mediaconvert_role_arn, default: -> {
      if lookup(:service_level).nil?
        # role that only gives access to dev bucket
        "arn:aws:iam::335460257737:role/scihist-digicoll-DEV-MediaConvertRole"
      end
    }

    define_key :lockbox_master_key, default: -> {
      # In production, we insist that local_env.yml contain
      # a real 64-bit key; if none is defined, we fail at
      # deploy time (see config/initializers/lockbox.rb).
      #
      # However, we do provide a dummy key for dev and test
      # environments, which is a string of 64 zeros.
      "0" * 64 if Rails.env.test? || Rails.env.development?
    }

    define_key :aws_region, default: "us-east-1"

    # eg "https://digital.sciencehistory.org", or "http://localhost:3000".
    # The first part of the URL for our app, as deployed in the current
    # setup.
    define_key :app_url_base, default: -> {
      # defaults for test/dev, otherwise insist on getting from local_env.yml,
      # no default.
      if Rails.env.test?
        # This seems to match what Rails/Capybara/Rspec are using/expect
        "http://127.0.0.1"
      elsif Rails.env.development?
        # hacky maybe not public API way to try to get current dev server
        require "rails/commands/server/server_command"
        server_options = Rails::Command::ServerCommand.new([], ARGV).server_options

        "#{server_options[:SSLEnable] ? 'https' : 'http'}://#{server_options[:Host] || ENV['HOST'] || 'localhost'}:#{server_options[:Port] || ENV['PORT'] || '3000'}"
      end
    }

    # Sometimes we need the individual parts of the app_base_url, returns a URI object
    # they can be obtained from.
    def self.app_url_base_parsed
      @app_url_base_parsed = URI.parse(lookup!(:app_url_base))
    end


    # We have a variety of places for "contact us", including some machine-readable
    # places like OAI-PMH config. they were previously all using this as a non-DRY
    # string literal.
    #
    # General questions:
    define_key :admin_email, default: "digital@sciencehistory.org"

    # Questions about rights and reproductions:
    define_key :reproductions_email, default: "reproductions@sciencehistory.org"

    define_key :opac_link_template, default: "https://othmerlib.sciencehistory.org/record=%s"

    define_key :main_website_base, default: "https://sciencehistory.org"

    # IPs at 315 chestnut
    define_key :main_office_ips,
      default: [ '173.161.142.4', '173.167.214.146'],
      system_env_transform: ->(v) {
        # YAML load can turn "['string', 'string']" into the array represented
        YAML.safe_load(v.to_s)
      }

    # set in ENV LOGINS_DISABLED or local_env.yml, to globally
    # prevent access to pages requiring authentication. May be useful
    # for maintenance tasks.
    define_key :logins_disabled, system_env_transform: Kithe::ConfigBase::BOOLEAN_TRANSFORM

    # https://www.cloudflare.com/application-services/products/turnstile/
    # Default to some always-good testing keys if in development
    # https://developers.cloudflare.com/turnstile/troubleshooting/testing/
    define_key :cf_turnstile_sitekey, default: ("1x00000000000000000000AA" if Rails.env.development?)
    define_key :cf_turnstile_secret_key, default: ("1x0000000000000000000000000000000AA" if Rails.env.development?)
    define_key :cf_turnstile_enabled, system_env_transform: Kithe::ConfigBase::BOOLEAN_TRANSFORM, default: false

    # EPHEMERAL_REDIS_CACHE_STORE_URL_ENV
    # should be set to the env key containing
    # redis instance's secure URL,
    # for instance
    # AH_REDIS_STACKHERO_JADE_URL_TLS
    define_key :ephemeral_redis_cache_store_url, default: ( ENV[ ENV['EPHEMERAL_REDIS_CACHE_STORE_URL_ENV'] ] unless ENV['EPHEMERAL_REDIS_CACHE_STORE_URL_ENV'].nil? )

    define_key :ephemeral_redis_pool_timeout,     default: 0.2
    define_key :ephemeral_redis_connect_timeout,  default: 1
    define_key :ephemeral_redis_read_timeout,     default: 0.2
    define_key :ephemeral_redis_write_timeout,    default: 0.2

    # Whether to cache the results of more_like_this SOLR queries.
    # see app/services/more_like_this_getter.rb
    define_key :cache_more_like_this, system_env_transform: Kithe::ConfigBase::BOOLEAN_TRANSFORM, default: false

    # Logic to get network location of the Redis instance we will
    # use for our "noeviction" (as opposed to ephemeral) rescue jobs queue.
    #
    # Does not cache/memoize, will create a new one on every call, thus the ! in name.
    #
    # @returns [Redis] some result of `Redis.new`
    #
    # * We use ENV['NOEVICTION_REDIS_PROVIDER_ENV'] to point to name of ENV that has the URL for the queue redis
    #
    # * If not found, we try some used by our various redis providers.)
    #
    # * otherwise default to default redis location "localhost:6379"
    #
    def self.persistent_noeviction_redis_connection!
      connection = nil

      # So many places the redis url can be, in a bit of indirection we use
      # REDIS_PROVIDER to point to the name of the ENV that has it!
      if ENV['NOEVICTION_REDIS_PROVIDER_ENV']
        noeviction_redis_url = ENV[ ENV['NOEVICTION_REDIS_PROVIDER_ENV'] ]
      end

      # we didn't find one, look in the various URLs that heroku redis or stack hero
      # might use, which of course we are also free to use locally etc.
      if noeviction_redis_url.blank?
        # def prever _TLS one with rediss: TLS connection if both alternatives are avail!
        # https://devcenter.heroku.com/articles/securing-heroku-redis
        noeviction_redis_url = ENV['REDIS_TLS_URL'] || ENV['REDIS_URL'] || ENV['STACKHERO_REDIS_URL_TLS']
      end

      if noeviction_redis_url
        ssl_params = {}
        # Heroku redis super annoyingly requires us to disable SSL verification.
        # https://devcenter.heroku.com/articles/securing-heroku-redis
        #
        # Super annoying, we default to disabling for an rediss secure connection
        # from REDIS_URL or REDIS_TLS_URL
        if noeviction_redis_url.start_with?("rediss:") && noeviction_redis_url.in?([ENV['REDIS_TLS_URL'], ENV['REDIS_URL']])
          ssl_params = { verify_mode: OpenSSL::SSL::VERIFY_NONE }
        end

        return Redis.new(url: noeviction_redis_url, ssl_params: ssl_params)
      elsif false && !Rails.env.production?
        # Still didn't find one? Probably in dev, just use default redis location.
        return Redis.new(url: "redis://localhost:6379")
      end

      error_message = "No 'noeviction' redis url could be found. Cannot provide!\n\n" +
       "NOEVICTION_REDIS_PROVIDER_ENV=='#{ENV['NOEVICTION_REDIS_PROVIDER_ENV']}' ;\n"
      if ENV['NOEVICTION_REDIS_PROVIDER_ENV']
        error_message += "ENV[ ENV['NOEVICTION_REDIS_PROVIDER_ENV'] ]=='#{ENV[ ENV['NOEVICTION_REDIS_PROVIDER_ENV'] ]}'\n"
      end
      Rails.logger.fatal("#{self.name}#persistent_noeviction_redis_connection! => #{error_message}")

      return nil
    end

    define_key :s3_bucket_originals
    define_key :s3_bucket_originals_video
    define_key :s3_bucket_derivatives
    define_key :s3_bucket_derivatives_video

    define_key :s3_bucket_uploads
    define_key :s3_bucket_on_demand_derivatives
    define_key :s3_bucket_dzi

    # if we are using CloudFront in front of a bucket, we set Cloudfront Distro hostname
    # in variables corresponding to bucket name env, with `_host` on the end. These
    # are all assumed cloudfront if set.
    #
    # All of these cloudfront hostnames are somewhat opaque, and can be found
    # from `terraform output` output from existing infrastructure, either staging
    # or prod.

    define_key :s3_bucket_originals_host
    define_key :s3_bucket_originals_video_host # not currently used as we don't provide access to originals
    define_key :s3_bucket_derivatives_host
    define_key :s3_bucket_derivatives_video_host
    define_key :s3_bucket_on_demand_derivatives_host
    define_key :s3_bucket_dzi_host

    # If we are using Cloudfront with restricted buckets, the key-pair id and RSA public
    # key need to be set.
    define_key :cloudfront_key_pair_id # from `terraform output`
    # private key can be found in 1password as:
    #   `scihist-digicoll-production_private_key.pem` or
    #   `scihist-digicoll-staging_private_key.pem`
    #
    #   Value needs to be exported from 1Password in `PKCS#8` format, will begin with
    #   '-----BEGIN PRIVATE KEY-----' [NOT 'OPENSSH PRIVATE KEY']
    define_key :cloudfront_private_key


    define_key :ingest_bucket, default: -> {
      if !Rails.env.production?
        # This bucket isn't actually mounted on workstations, but you can
        # add files to it in AWS console if you want files to test ingest
        # with in a dev environment.
        "scih-uploads-dev"
      end
      # In production we rely on local_env.yml to provide value, no default,
      # it'll just get out of sync.
    }

    define_key :force_ssl, default: Rails.env.production?, system_env_transform: Kithe::ConfigBase::BOOLEAN_TRANSFORM

    define_key :s3_sitemap_bucket, default: -> {
      # for now we keep Google sitemaps in our derivatives bucket
      ScihistDigicoll::Env.lookup(:s3_bucket_derivatives)
    }
    define_key :s3_sitemap_bucket_host, default: -> {
      # hacky way to deal with the fact that we need to use the cloudfront host as public host
      ScihistDigicoll::Env.lookup(:s3_bucket_derivatives_host)
    }
    define_key :sitemap_path, default: "__sitemaps/"


    # shared bucket for dev, everything will be on there
    define_key :s3_dev_bucket, default: "scih-data-dev"
    # shared between different users, let's segregate em
    define_key :s3_dev_prefix, default: -> { "#{ENV['USER']}.#{Socket.gethostname}" }



    # production is s3 buckets configured for production. dev_s3 is a single
    # s3 bucket, useful in dev. dev_file is local filesystem, default in test, can be useful
    # in dev.
    define_key :storage_mode, allows: ['production', 'dev_s3', 'dev_file'], default: -> {
      if Rails.env.production?
        'production'
      elsif Rails.env.test?
        'dev_file'
      elsif lookup(:aws_access_key_id) && lookup(:aws_secret_access_key)
        'dev_s3'
      else
        warn("ScihistDigicoll: Using STORAGE_MODE=dev_file, because we lack aws_access_key_id and aws_secret_access_key")
        'dev_file'
      end
    }

    # for legacy reasons this is a solr url WITH a collection name on the end, like
    # https://example.org/solr/collection_name
    #
    # See also solr_base_url and solr_collection_name methods which give you the parts
    define_key :solr_url, default: ->{
      # Note the ports used in dev/test must match ports in .solr_wrapper
      # if you want testing to work right and dev instance to talk to solr-wrapper
      # started dev solr.
      if Rails.env.test?
        "http://127.0.0.1:8989/solr/scihist_digicoll_test"
      elsif Rails.env.development?
        "http://127.0.0.1:8987/solr/scihist_digicoll_development"
      end
      # production we have no default, local env has to supply it
    }

    # config solr_url without collection_name, and without trailing slash
    def self.solr_base_url
      @solr_base_url ||= begin
        parsed = URI.parse(lookup!(:solr_url))
        parsed.path = parsed.path.gsub(%r{/solr/.*\Z}, "/solr")
        parsed.to_s
      end
    end

    # collection_name taken off the end of config solr_url
    def self.solr_collection_name
      @solr_collection_name ||= URI.parse(lookup!(:solr_url)).path.split("/").last
    end

    # If false, we will NOT write to solr on changes to Works/Collections/Assets.
    # Useful for when solr is not present in a testing/staging environment, and we
    # want to make it still possible to do admin work.
    define_key :solr_indexing, default: "true"

    # Supplied only on production servers.
    # The Google Analytics 4 tag has form         'G-XXXXXXXXXX'
    define_key :google_analytics_4_tag_id

    # Don't configure ActiveJob to automatically retry on failure in test, that would be a mess.
    define_key :activejob_auto_retry,
      system_env_transform: Kithe::ConfigBase::BOOLEAN_TRANSFORM,
      default: -> {
        ! Rails.env.test?
      }

    # Return appropriate Shrine::Storage instance for our mode (dev_file, dev_s3, or production),
    # and the bucket key.
    #
    # In dev_file, different bucket_keys are just different paths in a local filesystem dir
    # in public/
    #
    # In dev_s3, different bucket_keys are just different prefixes in a single shared dev bucket.
    # (bucket name in :s3_dev_bucket env, by default kithe-files-dev)
    #
    # In production, different bucket keys are actual keys to look up actual bucket names in the Env
    # system (local_env.yml or ENV), usually a different bucket per key.
    #
    # If you want to configure to have shrine treat the bucket as public (set public ACLs on upload
    # and generate public URLs by default), and you might also want to set far-future cache
    # headers, pass:
    #
    #      s3_storage_options: {
    #        public: true,
    #        upload_options: {
    #          # since shrine urls should be at random unique keys, we can cache forever
    #          cache_control: "max-age=31536000, public"
    #        }
    #      })
    #
    # @param bucket_key [String] required. in `production` mode this is the bucket name, otherwise
    #                            it becomes part of the prefix location.
    #
    # @param public [Boolean] (default false), if FALSE the storage requires signed URLs, and
    #                         we will set up shrine storage to generate them -- either using
    #                         AWS access key (direct), or Cloudfront public key (if host is set for
    #                         Cloudfront distro in front)
    #
    # @param prefix [String] prefix passed to shrine storage, a "directory" within the
    #                        storage. for dev_s3 and dev_file modes combined with
    #                        other pre-prefix.
    #
    # @param host [String] used only for `production` S3 mode, if set we assume a CloudFront CDN distro
    #                      on top of bucket, and set up url-generation accordingly, including with
    #                      Cloudfront-style signing (using env for cloudfront public key which will be required)
    #
    # @param s3_storage_options [Hash] passed directly to Shrine storage for S3 modes, additional
    #                                  arbitrary options. Can override other defaults or params.
    #
    # @param mode: [String] One of `production` (separate s3 buckets), `dev_s3` (single
    #                       shared multi-person s3 bucket), or `dev_file` (local
    #                       file system). Normally left unset, it will default to
    #                       env key :storage_mode, which is what you want it to do.
    #
    def self.appropriate_shrine_storage(bucket_key:, public: false, mode: lookup!(:storage_mode), prefix: nil,
                                        host: nil, s3_storage_options: {} )
      unless %I{s3_bucket_uploads s3_bucket_originals s3_bucket_originals_video s3_bucket_derivatives
                s3_bucket_derivatives_video
                s3_bucket_on_demand_derivatives s3_bucket_dzi}.include?(bucket_key)
        raise ArgumentError.new("Unrecognized bucket_key: #{bucket_key}")
      end

      # used in dev_file and dev_s3 modes:
      shared_bucket_path_prefix = [bucket_key.to_s.sub(/^s3_bucket_/, ''), prefix].compact.join("/")
      mode = mode.to_s

      if mode == "dev_file"
        Shrine::Storage::FileSystem.new("public", prefix: "shrine_storage_#{Rails.env}/#{shared_bucket_path_prefix}")
      elsif mode == "dev_s3"
        FasterS3Url::Shrine::Storage.new(**{
          bucket:            lookup(:s3_dev_bucket),
          prefix:            "#{lookup(:s3_dev_prefix)}/#{shared_bucket_path_prefix}",
          access_key_id:     lookup(:aws_access_key_id),
          secret_access_key: lookup(:aws_secret_access_key),
          region:            lookup(:aws_region),
          # Force a concrete, known-good CA bundle.
          # Fixes a bug with Ruby 3.4 + OpenSSL 3.5 on macOS in
          # which:
          #   SSLContext#cert_store starts out nil;
          #   somewhere in the AWS SDK / Net::HTTP stack,
          #     a cert store was being constructed implicitly,
          #     which triggered CRL expectations,
          #       leading to an "unable to get certificate CRL" error
          #       even though the certificate chain was valid.
          #
          # See also https://github.com/sciencehistory/scihist_digicoll/issues/3236
          #
          ssl_ca_bundle:     OpenSSL::X509::DEFAULT_CERT_FILE
        }.merge(s3_storage_options))
      elsif mode == "production"
        if host.present?
          # Assumed cloudfront if we have a host!
          ScihistDigicoll::ShrineStorage::CloudfrontS3Storage.new(**{
            bucket:            lookup!(bucket_key),
            host:              host,
            public:            public,
            prefix:            prefix,
            access_key_id:     lookup!(:aws_access_key_id),
            secret_access_key: lookup!(:aws_secret_access_key),
            region:            lookup!(:aws_region),
            cloudfront_key_pair_id:     lookup(:cloudfront_key_pair_id),
            cloudfront_private_key: lookup(:cloudfront_private_key)
          }.merge(s3_storage_options))
        else
          FasterS3Url::Shrine::Storage.new(**{
            bucket:            lookup!(bucket_key),
            public:            public,
            prefix:            prefix,
            access_key_id:     lookup!(:aws_access_key_id),
            secret_access_key: lookup!(:aws_secret_access_key),
            region:            lookup!(:aws_region)
          }.merge(s3_storage_options))
        end
      else
        raise TypeError.new("unrecognized storage mode: #{mode}")
      end
    end

    # Based on config, supply appropriate shrine cache.
    def self.shrine_cache_storage
      @shrine_cache_storage ||=
        # special handling with "web" prefix, I forget why.
        appropriate_shrine_storage( bucket_key: :s3_bucket_uploads,
                                    prefix: "web")
    end

    def self.shrine_store_storage
      @shrine_store_storage ||=
        appropriate_shrine_storage(bucket_key: :s3_bucket_originals, public: false, host: lookup(:s3_bucket_originals_host))
    end

    # we store video originals in separate location
    def self.shrine_store_video_storage
      @shrine_video_store_storage ||=
        appropriate_shrine_storage(bucket_key: :s3_bucket_originals_video, public: false, host: lookup(:s3_bucket_originals_video_host))
    end

    # Note we set shrine S3 storage to public, to upload with public ACLs
    def self.shrine_derivatives_storage
      @shrine_derivatives_storage ||=
        appropriate_shrine_storage( bucket_key: :s3_bucket_derivatives,
                                    host: lookup(:s3_bucket_derivatives_host),
                                    public: true,
                                    s3_storage_options: {
                                      upload_options: {
                                        # derivatives are public and at unique random URLs, so
                                        # can be cached far-future
                                        cache_control: "max-age=31536000, public"
                                      }
                                    })
    end

    def self.shrine_video_derivatives_storage
      @shrine_derivatives_video_storage ||=
        appropriate_shrine_storage( bucket_key: :s3_bucket_derivatives_video,
                                    host: lookup(:s3_bucket_derivatives_video_host),
                                    public: true,
                                    s3_storage_options: {
                                      upload_options: {
                                        # derivatives are public and at unique random URLs, so
                                        # can be cached far-future
                                        cache_control: "max-age=31536000, public"
                                      }
                                    })
    end

    # RESTRICTED derivative storage. We keep these in a separate prefix in
    # ORIGINALS bucket, since originals bucket already has the access restrictions
    # we need, and backups, etc.
    def self.shrine_restricted_derivatives_storage
      @shrine_restricted_derivatives_storage ||=
        appropriate_shrine_storage( bucket_key: :s3_bucket_originals,
                                    host: lookup(:s3_bucket_originals_host),
                                    public: false,
                                    prefix: "restricted_derivatives")
    end

    # Note we set shrine S3 storage to public, to upload with public ACLs
    def self.shrine_on_demand_derivatives_storage
      @shrine_on_demand_derivatives_storage ||=
        appropriate_shrine_storage( bucket_key: :s3_bucket_on_demand_derivatives,
                                    host: lookup(:s3_bucket_on_demand_derivatives_host),
                                    public: true,
                                    s3_storage_options: {
                                      upload_options: {
                                        # these have fingerprints in their URLs, so they are
                                        # cacheable forever. only started setting this in Jul 2024
                                        cache_control: "max-age=31536000, public"
                                      }
                                    }
                                  )
    end

    def self.shrine_combined_audio_derivatives_storage
      # store in same bucket as derivatives, with separate prefix
      @shrine_combined_audio_derivatives_storage ||=
        appropriate_shrine_storage( bucket_key: :s3_bucket_derivatives,
                                    host: lookup(:s3_bucket_derivatives_host),
                                    prefix: "combined_audio_derivatives",
                                    public: true,
                                    s3_storage_options: {
                                      upload_options: {
                                        # these have fingerprints in their URLs, so they are
                                        # cacheable forever. only started setting this in Jul 2024
                                        cache_control: "max-age=31536000, public"
                                      }
                                    })
    end

    def self.shrine_dzi_storage
      @shrine_dzi_storage ||=
        appropriate_shrine_storage( bucket_key: :s3_bucket_dzi,
                                    host: lookup(:s3_bucket_dzi_host),
                                    public: true,
                                    s3_storage_options: {
                                      upload_options: {
                                        # our DZI's are all public right now, and at unique-to-content
                                        # URLs, cache forever.
                                        cache_control: "max-age=31536000, public"
                                      }
                                    })
    end


    # S3 buckets for backups. Mostly used in Rake tasks.
    define_key :s3_bucket_derivatives_backup
    define_key :s3_bucket_dzi_backup


    define_key :s3_backup_file_path
    define_key :s3_backup_bucket_region
    define_key :s3_backup_access_key_id
    define_key :s3_backup_secret_access_key
    # Returns an S3::Bucket for the derivatives backup, used by our derivative storage
    # type mover to make sure non-public derivatives don't exist in backups either.
    #
    # Can return nil if not defined!
    def self.derivatives_backup_bucket
      unless defined?(@derivatives_backup_bucket)
        @derivatives_backup_bucket = begin
          bucket_name = lookup(:s3_bucket_derivatives_backup)
          region      = lookup(:s3_backup_bucket_region)

          if bucket_name.present? && region.present?
            client = Aws::S3::Client.new(
              access_key_id:     lookup(:aws_access_key_id),
              secret_access_key: lookup(:aws_secret_access_key),
              region: region)

            Aws::S3::Bucket.new(name: bucket_name, client: client)
          elsif production?
            raise RuntimeError.new("In production tier, but missing derivatives backup bucket settings presumed to exist")
          end
        end
      end

      @derivatives_backup_bucket
    end

    # Returns an S3::Bucket for the DZI backup, used by our derivative storage
    # type mover to make sure non-public derivatives don't exist in backups either.
    #
    # Can return nil if no defined!
    def self.dzi_backup_bucket
      unless defined?(@dzi_backup_bucket)
        @dzi_backup_bucket = begin
          bucket_name = lookup(:s3_bucket_dzi_backup)
          region      = lookup(:s3_backup_bucket_region)

          if bucket_name.present? && region.present?
            client = Aws::S3::Client.new(
              access_key_id:     lookup(:aws_access_key_id),
              secret_access_key: lookup(:aws_secret_access_key),
              region: region)

            Aws::S3::Bucket.new(name: bucket_name, client: client)
          end
        end
      end

      @dzi_backup_bucket
    end


    define_key :honeybadger_api_key

    define_key :openai_api_key

    # nil means use default, but we can define if we want to put all OCR work on, say, `special_jobs`.
    define_key :active_job_ocr_queue

    # Used for sending mail, and if no queue is specified:
    define_key :regular_job_worker_count, default: -> {
      Rails.env.production? ? 1 : 0
    }
    # Used for generating PDFs or Zip files requested by users on the front end:
    define_key :on_demand_job_worker_count, default: -> {
      Rails.env.production? ? 1 : 0
    }
    # Used (infrequently) by additional special_worker job
    # servers whose only purpose is to handle special tasks:
    define_key :special_job_worker_count, default: 2


    # SPECIFIC COLLECTION IDS
    # Used to trigger custom controllers/UI for specific known collections
    define_key :oral_history_collection_id, default: "gt54kn818"
    define_key :immigrants_and_innovation_collection_id, default: "wkppqzw"
    define_key :bredig_collection_id, default: "qfih5hl"

    # hostname for legacy Oral History microsite, we catch requests to this
    # and redirect appropriately.
    define_key :oral_history_legacy_host, default: "oh.sciencehistory.org"

    # OUTGOING EMAIL:

    # From address:
    define_key :no_reply_email_address, default: "no-reply@sciencehistory.org"
    define_key :oral_history_email_address, default: "oralhistory@sciencehistory.org"

    # To addresses (these are email lists maintained by IT.)
    define_key :digital_tech_email_address, default: "digital-tech@sciencehistory.org"
    define_key :digital_email_address, default: "digital@sciencehistory.org"
    # requested simple email alerting for Digitization Queue creation, unset to disable feature
    define_key :digitization_queue_alerts_email_address, default: "digital@sciencehistory.org"

    # These are the credentials used for accessing Amazon's simple email server:
    define_key :smtp_username
    define_key :smtp_password
    define_key :smtp_host

    # The value for :rails_asset_host can be obtained by running `terraform output`.
    define_key :rails_asset_host

    ##
    #
    # feature flags: We can use Env to be a place where feature flags that hide under-development
    # features live.
    #
    ###

    # Example:
    # define_key "feature_fulltext_search", default: -> {
    #   # for now default false in real production true elsewhere
    #   ScihistDigicoll::Env.staging? || !Rails.env.production?
    # }, system_env_transform: Kithe::ConfigBase::BOOLEAN_TRANSFORM

    define_key "feature_search_inside_work", default: true, system_env_transform: Kithe::ConfigBase::BOOLEAN_TRANSFORM

    define_key "disable_downloads", default: false, system_env_transform: Kithe::ConfigBase::BOOLEAN_TRANSFORM
  end
end
