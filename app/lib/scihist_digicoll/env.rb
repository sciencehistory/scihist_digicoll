require 'socket'
require "shrine/storage/file_system"
require "shrine/storage/s3"

module ScihistDigicoll
  class Env < Kithe::ConfigBase
    # look for config/local_env.yml, and if we're NOT in production,
    # config/local_env_#{env}.yml

    rails_env = defined?(Rails) ? Rails.env.to_s : (ENV["RAILS_ENV"] || "development")
    if rails_env != "development" && rails_env != "test"
      self.config_file_paths = ["config/local_env.yml"]
    else
      self.config_file_paths = ["config/local_env.yml", "config/local_env_#{rails_env.downcase}.yml"]
    end

    define_key :aws_access_key_id
    define_key :aws_secret_access_key

    define_key :aws_region, default: "us-east-1"

    # shared bucket for dev, everything will be on there
    # This bucket name is not right. Really confused what the buckets are.
    define_key :s3_dev_bucket, default: "kithe-files-dev"
    # shared between different users, let's segregate em
    define_key :s3_dev_prefix, default: -> { "#{ENV['USER']}.#{Socket.gethostname}" }

    define_key :ingest_bucket, default: -> {
      if Rails.env.production?
        nil # to do
      else
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
        Shrine::Storage::FileSystem.new("tmp/shrine_storage_testing", prefix: "cache")
      when "dev_s3"
        Shrine::Storage::S3.new({
          bucket:            lookup(:s3_dev_bucket),
          prefix:            "#{lookup(:s3_dev_prefix)}/shrine_cache",
          access_key_id:     lookup(:aws_access_key_id),
          secret_access_key: lookup(:aws_secret_access_key),
          region:            lookup(:aws_region)
        })
      when "production"
        raise TypeError.new("not yet implemented")
      else
        raise TypeError.new("unrecognized storage mode")
      end
    end

    def self.shrine_store_storage
      case lookup!(:storage_mode)
      when "dev_file"
        Shrine::Storage::FileSystem.new("tmp/shrine_storage_testing", prefix: "store")
      when "dev_s3"
        Shrine::Storage::S3.new({
          bucket:            lookup(:s3_dev_bucket),
          prefix:            "#{lookup(:s3_dev_prefix)}/shrine_store",
          access_key_id:     lookup(:aws_access_key_id),
          secret_access_key: lookup(:aws_secret_access_key),
          region:            lookup(:aws_region)
      })
      when "production"
        raise TypeError.new("not yet implemented")
      else
        raise TypeError.new("unrecognized storage mode")
      end
    end

    # Note we set shrine S3 storage to public, to upload with public ACLs
    def self.shrine_derivatives_storage
      case lookup!(:storage_mode)
      when "dev_file"
        Shrine::Storage::FileSystem.new("tmp/shrine_storage_testing", prefix: "derivatives")
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
        raise TypeError.new("not yet implemented")
      else
        raise TypeError.new("unrecognized storage mode")
      end
    end


  end
end
