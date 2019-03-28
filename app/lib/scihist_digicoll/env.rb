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
  # most convenient.
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

    define_key :secret_key_base
    define_key :service_level, allows: ["stage", "prod", nil]

    # Rails-style db url, eg postgres://myuser:mypass@localhost/somedatabase
    define_key :rails_database_url

    define_key :aws_access_key_id
    define_key :aws_secret_access_key

    define_key :aws_region, default: "us-east-1"

    # where our web app is located, https://WHAT
    define_key :web_hostname

    define_key :opac_link_template, default: "https://othmerlib.sciencehistory.org/record=%s"

    # set in ENV LOGINS_DISABLED or local_env.yml, to globally
    # prevent access to pages requiring authentication. May be useful
    # for maintenance tasks.
    define_key :logins_disabled, system_env_transform: Kithe::ConfigBase::BOOLEAN_TRANSFORM

    define_key :s3_bucket_originals
    define_key :s3_bucket_derivatives
    define_key :s3_bucket_uploads

    # For ActiveJob queue, among maybe other things.
    define_key :persistent_redis_host, default: "localhost:6379"

    # shared bucket for dev, everything will be on there
    # This bucket name is not right. Really confused what the buckets are.
    define_key :s3_dev_bucket, default: "kithe-files-dev"
    # shared between different users, let's segregate em
    define_key :s3_dev_prefix, default: -> { "#{ENV['USER']}.#{Socket.gethostname}" }

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

    # Based on config, supply appropriate shrine cache.
    def self.shrine_cache_storage
      case lookup!(:storage_mode)
      when "dev_file"
        Shrine::Storage::FileSystem.new("public", prefix: "shrine_storage_#{Rails.env}/cache")
      when "dev_s3"
        Shrine::Storage::S3.new({
          bucket:            lookup(:s3_dev_bucket),
          prefix:            "#{lookup(:s3_dev_prefix)}/shrine_cache",
          access_key_id:     lookup(:aws_access_key_id),
          secret_access_key: lookup(:aws_secret_access_key),
          region:            lookup(:aws_region)
        })
      when "production"
        Shrine::Storage::S3.new({
          bucket:            lookup(:s3_bucket_uploads),
          prefix:            "web",
          access_key_id:     lookup(:aws_access_key_id),
          secret_access_key: lookup(:aws_secret_access_key),
          region:            lookup(:aws_region)
        })
      else
        raise TypeError.new("unrecognized storage mode")
      end
    end

    def self.shrine_store_storage
      case lookup!(:storage_mode)
      when "dev_file"
        Shrine::Storage::FileSystem.new("public", prefix: "shrine_storage_#{Rails.env}/store")
      when "dev_s3"
        Shrine::Storage::S3.new({
          bucket:            lookup(:s3_dev_bucket),
          prefix:            "#{lookup(:s3_dev_prefix)}/shrine_store",
          access_key_id:     lookup(:aws_access_key_id),
          secret_access_key: lookup(:aws_secret_access_key),
          region:            lookup(:aws_region)
      })
      when "production"
        Shrine::Storage::S3.new({
          bucket:            lookup(:s3_bucket_originals),
          access_key_id:     lookup(:aws_access_key_id),
          secret_access_key: lookup(:aws_secret_access_key),
          region:            lookup(:aws_region)
        })
      else
        raise TypeError.new("unrecognized storage mode")
      end
    end

    # Note we set shrine S3 storage to public, to upload with public ACLs
    def self.shrine_derivatives_storage
      case lookup!(:storage_mode)
      when "dev_file"
        Shrine::Storage::FileSystem.new("public", prefix: "shrine_storage_#{Rails.env}/derivatives")
      when "dev_s3"
        Shrine::Storage::S3.new({
          bucket:            lookup(:s3_dev_bucket),
          prefix:            "#{lookup(:s3_dev_prefix)}/derivatives",
          access_key_id:     lookup(:aws_access_key_id),
          secret_access_key: lookup(:aws_secret_access_key),
          region:            lookup(:aws_region),
          public: true
        })
      when "production"
        Shrine::Storage::S3.new({
          bucket:            lookup(:s3_bucket_derivatives),
          access_key_id:     lookup(:aws_access_key_id),
          secret_access_key: lookup(:aws_secret_access_key),
          region:            lookup(:aws_region),
          public: true
        })
      else
        raise TypeError.new("unrecognized storage mode")
      end
    end


    define_key :honeybadger_api_key

    # Only used for our import from sufia script, username/password to fetch
    # bytestreams from fedora.
    define_key :import_fedora_auth

  end
end
