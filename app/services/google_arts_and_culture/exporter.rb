require 'open-uri'
require 'zip'
require "google/cloud/storage"
require "googleauth"

module GoogleArtsAndCulture
  class Exporter
    attr_reader :scope, :callback

    def initialize(scope, callback: nil, columns: nil)
      @scope = scope
      @callback = callback
      @attribute_keys = if columns.nil?
        all_attributes.keys
      else
        columns.select { |c| all_attributes.keys.include? c }
      end
    end

    def upload_files_to_google_arts_and_culture
      UploadFilesToGoogleArtsAndCultureJob.perform_later(
        work_ids: @scope.pluck(:id),
        attribute_keys: @attribute_keys,
        column_counts: column_counts
      )
    end


    # Does not close the tempfile.
    def metadata_csv_tempfile
      output_csv_file = Tempfile.new
      CSV.open(output_csv_file, "wb") do |csv|
        self.metadata.each { |row| csv << row }
      end
      output_csv_file
    end

    def metadata
      @metadata ||= begin
        data = []
        data << title_row
        @scope.includes(:leaf_representative).each do |work|
          data.append *GoogleArtsAndCulture::WorkSerializer.new(work, attribute_keys: @attribute_keys, column_counts: column_counts).metadata
        end
        data
      end
    end

    def tmp_zipfile!
      Tempfile.new(["GAC_download", ".zip"]).tap { |t| t.binmode }
    end

    def title_row
      # if a given attribute stretches over several columns, label the columns correctly (creator#0, creator#1, creator#2, etc.)
      @attribute_keys.map do |k|
        if array_attributes.include? k.to_s
          (0..(column_counts[k.to_s] - 1)).map do |i|
            "#{ all_attributes[k ]}##{ i }"
           end
        else
          all_attributes[k]
        end
      end.flatten
    end

    # We store multiple values for each of these types of metadata. Note that we don't make much of an attempt to
    # distinguish creator categories, at least for now.
    # Likewise, `external_id` is treated as an array, with categories ignored.
    def array_attributes
      [
        'subject',
        'external_id',
        'additional_title',
        'genre',
        'creator',
        'medium',
        'extent',
        'place',
        'format',
      ]
    end

    # Count of of columns we need for each array attribute.
    def column_counts
      @column_counts ||= Hash[
          array_attributes.zip(
          @scope.pluck(
              *array_attributes.map { |c| column_max_arel c }
          ).first
        )
      ]
    end

    # sql to determine the maximum number of columns needed for a multiple-column attribute
    def column_max_arel(attribute_name)
      Arel.sql("max(jsonb_array_length(kithe_models.json_attributes -> '#{attribute_name}'))" )
    end

    # A hash of possible columns
    # you can use in the report.
    # Keys are our methods; values are the column titles GAC accepts.
    #
    # By default, the report contains all these columns,
    # but you can pass `columns` to return fewer.
    #
    # Note that the titles are not arbitrary: they need to be recognized GAC metadata labels
    # (as documented at https://support.google.com/culturalinstitute/partners/answer/4618071?hl=en and so on).
    def all_attributes
      @all_attributes ||= {
        # friendlier_id of works
        friendlier_id:            'itemid',

        # friendlier_id of assets
        subitem_id:               'subitemid',    

        # order of assets within a work
        order_id:                 'orderid',

        # title (a string)
        title:                    'title',

        # GAC doesn't accept multiple titles, but we are including them anyway
        additional_title:         'customtext:additional_title',

        # name of the downloaded asset file
        file_name:                 'filespec',

        # 'Sequence' for works, 'Image' for image assets
        filetype:                 'filetype',

        # for linking back to the digital collections
        url_text:                 'relation:text',
        url:                      'relation:url',

        # Non-publisher creators
        creator:                  'creator',

        # Publisher(s). Separated by commas; we don't have a lot of works with multiple publishers.
        publisher:                'publisher',

        subject:                   'subject',

        # GAC's 'format' is used for our 'extent' metadata.
        extent:                   'format',
        
        # Dates:
        min_date:                 'dateCreated:start',
        max_date:                 'dateCreated:end',
        date_of_work:             'dateCreated:display',

        place:                    'locationCreated:placename',
        medium:                   'medium',
        genre:                    'art=genre',
        description:              'description',


        rights:                    'rights',
        rights_holder:             'customtext:rights_holder',

        # GAC doesn't seem to have a field for what we call "format"
        # format:                   '???',
      }
    end
  end
end