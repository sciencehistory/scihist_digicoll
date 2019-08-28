require 'socket'
require "shrine/storage/file_system"
require "shrine/storage/s3"


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



    # Rails-style db url, eg postgres://myuser:mypass@localhost/somedatabase
    define_key :rails_database_url

    define_key :aws_access_key_id
    define_key :aws_secret_access_key

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
        "http://localhost:3000"
      end
    }

    # Sometimes we need the individual parts of the app_base_url, returns a URI object
    # they can be obtained from.
    def self.app_url_base_parsed
      @app_url_base_parsed = URI.parse(lookup!(:app_url_base))
    end

    # We have a variety of places for "contact us", including some machine-readable
    # places like OAI-PMH config. they were previously all using this as a non-DRY
    # string literal, let's centralize it.
    define_key :admin_email, default: "digital@sciencehistory.org"

    define_key :opac_link_template, default: "https://othmerlib.sciencehistory.org/record=%s"

    # set in ENV LOGINS_DISABLED or local_env.yml, to globally
    # prevent access to pages requiring authentication. May be useful
    # for maintenance tasks.
    define_key :logins_disabled, system_env_transform: Kithe::ConfigBase::BOOLEAN_TRANSFORM

    # For ActiveJob queue, among maybe other things.
    define_key :persistent_redis_host, default: "localhost:6379"

    define_key :s3_bucket_originals
    define_key :s3_bucket_derivatives
    define_key :s3_bucket_uploads
    define_key :s3_bucket_on_demand_derivatives
    define_key :s3_bucket_dzi

    define_key :ingest_bucket, default: -> {
      if Rails.env.production?
        # This bucket is mounted on some staff Windows workstations
        # We use it in both production and staging environments.
        # But dev AWS key does not currently have access to it.
        "scih-uploads"
      else
        # This bucket isn't actually mounted on workstations, but you can
        # add files to it in AWS console if you want files to test ingest
        # with in a dev environment.
        "scih-uploads-dev"
      end
    }

    define_key :s3_sitemap_bucket, default: -> {
      # for now we keep Google sitemaps in our derivatives bucket
      ScihistDigicoll::Env.lookup(:s3_bucket_derivatives)
    }
    define_key :sitemap_path, default: "__sitemaps/"


    # shared bucket for dev, everything will be on there
    # This bucket name is not right. Really confused what the buckets are.
    define_key :s3_dev_bucket, default: "kithe-files-dev"
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

    # Supplied only on production servers, should have form 'UA-XXXXX-Y'
    define_key :google_analytics_property_id

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
    def self.appropriate_shrine_storage(bucket_key:, mode: lookup!(:storage_mode), s3_storage_options: {})
      unless %I{s3_bucket_uploads s3_bucket_originals s3_bucket_derivatives
                s3_bucket_on_demand_derivatives s3_bucket_dzi}.include?(bucket_key)
        raise ArgumentError.new("Unrecognized bucket_key: #{bucket_key}")
      end

      # used in dev_file and dev_s3 modes:
      path_prefix = bucket_key.to_s.sub(/^s3_bucket_/, '')
      mode = mode.to_s

      if mode == "dev_file"
        Shrine::Storage::FileSystem.new("public", prefix: "shrine_storage_#{Rails.env}/#{path_prefix}")
      elsif mode == "dev_s3"
        Shrine::Storage::S3.new({
          bucket:            lookup(:s3_dev_bucket),
          prefix:            "#{lookup(:s3_dev_prefix)}/#{path_prefix}",
          access_key_id:     lookup(:aws_access_key_id),
          secret_access_key: lookup(:aws_secret_access_key),
          region:            lookup(:aws_region)
        }.merge(s3_storage_options))
      elsif mode == "production"
        Shrine::Storage::S3.new({
          bucket:            lookup(bucket_key),
          access_key_id:     lookup(:aws_access_key_id),
          secret_access_key: lookup(:aws_secret_access_key),
          region:            lookup(:aws_region)
        }.merge(s3_storage_options))
      else
        raise TypeError.new("unrecognized storage mode: #{mode}")
      end
    end

    # Based on config, supply appropriate shrine cache.
    def self.shrine_cache_storage
      @shrine_cache_storage ||=
        # special handling with "web" prefix, I forget why.
        appropriate_shrine_storage( bucket_key: :s3_bucket_uploads,
                                    s3_storage_options: {
                                      prefix: "web"
                                    })
    end

    def self.shrine_store_storage
      @shrine_store_storage ||=
        appropriate_shrine_storage(bucket_key: :s3_bucket_originals)
    end

    # Note we set shrine S3 storage to public, to upload with public ACLs
    def self.shrine_derivatives_storage
      @shrine_derivatives_storage ||=
        appropriate_shrine_storage( bucket_key: :s3_bucket_derivatives,
                                    s3_storage_options: {
                                      public: true
                                    })
    end

    # Note we set shrine S3 storage to public, to upload with public ACLs
    def self.shrine_on_demand_derivatives_storage
      @shrine_on_demand_derivatives_storage ||=
        appropriate_shrine_storage( bucket_key: :s3_bucket_on_demand_derivatives,
                                    s3_storage_options: {
                                      public: true
                                    })
    end

    def self.shrine_dzi_storage
      @shrine_dzi_storage ||=
        appropriate_shrine_storage( bucket_key: :s3_bucket_dzi,
                                    s3_storage_options: {
                                      public: true,
                                      upload_options: {
                                        # our DZI's are all public right now, and at unique-to-content
                                        # URLs, cache forever.
                                        cache_control: "max-age=31536000,public"
                                      }
                                    })
    end

    define_key :honeybadger_api_key

    # Only used for our import from sufia script, username/password to fetch
    # bytestreams from fedora.
    define_key :import_fedora_auth

  end
end
