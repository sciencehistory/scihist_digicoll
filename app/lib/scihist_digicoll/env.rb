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
      if !Rails.env.production?
        # This bucket isn't actually mounted on workstations, but you can
        # add files to it in AWS console if you want files to test ingest
        # with in a dev environment.
        "scih-uploads-dev"
      end
      # In production we rely on local_env.yml to provide value, no default,
      # it'll just get out of sync.
    }

    define_key :s3_sitemap_bucket, default: -> {
      # for now we keep Google sitemaps in our derivatives bucket
      ScihistDigicoll::Env.lookup(:s3_bucket_derivatives)
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
    #
    def self.appropriate_shrine_storage(bucket_key:, mode: lookup!(:storage_mode), s3_storage_options: {}, prefix: nil)
      unless %I{s3_bucket_uploads s3_bucket_originals s3_bucket_derivatives
                s3_bucket_on_demand_derivatives s3_bucket_dzi}.include?(bucket_key)
        raise ArgumentError.new("Unrecognized bucket_key: #{bucket_key}")
      end

      # used in dev_file and dev_s3 modes:
      shared_bucket_path_prefix = [bucket_key.to_s.sub(/^s3_bucket_/, ''), prefix].compact.join("/")
      mode = mode.to_s

      if mode == "dev_file"
        Shrine::Storage::FileSystem.new("public", prefix: "shrine_storage_#{Rails.env}/#{shared_bucket_path_prefix}")
      elsif mode == "dev_s3"
        Shrine::Storage::S3.new({
          bucket:            lookup(:s3_dev_bucket),
          prefix:            "#{lookup(:s3_dev_prefix)}/#{shared_bucket_path_prefix}",
          access_key_id:     lookup(:aws_access_key_id),
          secret_access_key: lookup(:aws_secret_access_key),
          region:            lookup(:aws_region)
        }.merge(s3_storage_options))
      elsif mode == "production"
        Shrine::Storage::S3.new({
          bucket:            lookup(bucket_key),
          prefix:            prefix,
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
                                      public: true,
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
                                    prefix: "restricted_derivatives")
    end

    # Note we set shrine S3 storage to public, to upload with public ACLs
    def self.shrine_on_demand_derivatives_storage
      @shrine_on_demand_derivatives_storage ||=
        appropriate_shrine_storage( bucket_key: :s3_bucket_on_demand_derivatives,
                                    s3_storage_options: {
                                      public: true
                                    })
    end

    def self.shrine_combined_audio_derivatives_storage
      # store in same bucket as derivatives, with separate prefix
      @shrine_combined_audio_derivatives_storage ||=
        appropriate_shrine_storage( bucket_key: :s3_bucket_derivatives,
                                    prefix: "combined_audio_derivatives",
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
                                        cache_control: "max-age=31536000, public"
                                      }
                                    })
    end


    # Location of some backup buckets we sometimes need to purge files from
    define_key :s3_derivatives_backup_bucket
    define_key :s3_dzi_backup_bucket
    define_key :s3_backup_bucket_region

    # Returns an S3::Bucket for the derivatives backup, used by our derivative storage
    # type mover to make sure non-public derivatives don't exist in backups either.
    #
    # Can return nil, except in production will raise instead of nil, to make sure
    # we don't accidentally avoid deleting from backup bucket in production where
    # we assume it must exist.
    def self.derivatives_backup_bucket
      bucket_name = lookup(:s3_derivatives_backup_bucket)
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

    # Returns an S3::Bucket for the DZI backup, used by our derivative storage
    # type mover to make sure non-public derivatives don't exist in backups either.
    #
    # Can return nil, except in production will raise instead of nil, to make sure
    # we don't accidentally avoid deleting from backup bucket in production where
    # we assume it must exist.
    def self.dzi_backup_bucket
      bucket_name = lookup(:s3_dzi_backup_bucket)
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


    define_key :honeybadger_api_key



    # Used for sending mail, and if no queue is specified:
    define_key :regular_job_worker_count, default: 0
    # Used for generating PDFs or Zip files requested by users on the front end:
    define_key :on_demand_job_worker_count, default: 0
    # Used (infrequently) by additional job servers whose only purpose is to handle special tasks:
    define_key :special_job_worker_count, default: 0


    # OUTGOING EMAIL:

    # From address:
    define_key :no_reply_email_address, default: "no-reply@sciencehistory.org"
    # To addresses (these are email lists maintained by IT.)
    define_key :digital_tech_email_address, default: "digital-tech@sciencehistory.org"
    define_key :digital_email_address, default: "digital@sciencehistory.org"

    # These are the credentials used for accessing Amazon's simple email server:
    define_key :smtp_username
    define_key :smtp_password
    define_key :smtp_host

    ##
    #
    # feature flags: We can use Env to be a place where feature flags that hide under-development
    # features live.
    #
    ###

    # Example:
    # define_key "feature.fulltext_search", default: -> {
    #   # for now default false in real production true elsewhere
    #   ScihistDigicoll::Env.staging? || !Rails.env.production?
    # }


  end
end
