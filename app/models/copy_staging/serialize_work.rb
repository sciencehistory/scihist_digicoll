module CopyStaging
  # Serializes a work as JSON, along with info on storage buckets files are stored in.
  # Used by the scihist:copy_staging_work:serialize_work rake task, which is used by
  # the `heroku:copy_data` rake task. This is normally run on a staging server.
  #
  # All of this is to copy works from staging to a local dev instance.
  #
  # See also corresponding RestoreWork model. The JSON generated by this model
  # is consumed by that one, so must match.
  #
  #     SerializeWork.new(work).as_json #=> Hash
  #     SerializeWork.new(work).to_json #=> serialized string
  #
  class SerializeWork
    attr_accessor :work

    def initialize(work)
      @work = work
    end

    def as_json
      {
        "models" => serialized_models,
        "shrine_s3_storage_staging" => storages
      }
    end

    def to_json
      as_json.to_json
    end

    private

    # * The main work for this serializer
    # * all it's children (recursively, for multi-level nested)
    # * Any OralHistoryContent "sidecar" for main work (we don't bother checking children, cause
    #   we don't do that with our data right now)
    #
    # They are all serialized as a one item hash, with model name as key, and
    # attributes as value.
    #
    # We try to serialize in order, so restoring in order will not violate any foreign
    # key referential integrity. But circular foreign key referential integrity on parent/representative
    # for children makes that not entirely possible.
    def serialized_models
      serialize_model(work)
    end

    # A method called recursively, initially by #serialized_models, to get all children
    def serialize_model(model)
      model_attributes = model.attributes

      oral_history_content = []

      if model.kind_of?(Kithe::Asset)
        # hacky workaround
        # https://github.com/sciencehistory/kithe/pull/75
        model_attributes.delete("representative_id")
        model_attributes.delete("leaf_representative_id")
      elsif model.kind_of?(Work) && model.oral_history_content
        oral_history_content << { model.oral_history_content.class.name => model.oral_history_content.attributes.except("id") }
      end

      mine = [{ model.class.name => model_attributes }]

      children = model.members.flat_map do |member|
        serialize_model(member)
      end

      mine + children + oral_history_content
    end

    def shrine_config(shrine_storage_key)
      storage = Shrine.storages[shrine_storage_key.to_sym]

      unless storage.kind_of?(Shrine::Storage::S3)
        raise ArgumentError, "We only know how to work with S3 storage for Shrine.storages[:store], not #{storage.class.name}"
      end

      {
        "bucket_name" => storage.bucket.name,
        "prefix" => storage.prefix
      }
    end

    # The list of Shrine storages we can copy from and to
    # is listed as a constant in
    # CopyStaging::RestoreWok, so let's use that here.
    def storages
      storage_list = CopyStaging::RestoreWork::ORIGINALS_STORAGE + CopyStaging::RestoreWork::DERIVATIVES_STORAGE
      Hash[ storage_list.collect { |v| [v.to_s, shrine_config(v)  ] } ]
    end

  end
end
