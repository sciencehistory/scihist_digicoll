require 'open-uri'
require 'zip'

module GoogleArtsAndCulture
  class Exporter
    attr_reader :original_scope, :scope

    def initialize(scope, columns: nil)
      @original_scope = scope
      @scope = scope.where(published: true, type: "Work")

      raise StandardError, "No works in scope." unless @scope.count > 0

      @attribute_keys = if columns.nil?
        all_attributes.keys
      else
        columns.select { |c| all_attributes.keys.include? c }
      end
    end

    # Only works within this scope should be exported to Google Arts and Culture.
    def self.eligible_scope
      museum_scope = Work.where(published: true).
      where("json_attributes -> 'department' ?| array[:depts  ]", depts:   ['Museum'] ).
      where("json_attributes -> 'format'     ?| array[:formats]", formats: ['physical_object'] ).
      where("json_attributes -> 'rights'     ?| array[:rights ]", rights:  ['https://creativecommons.org/licenses/by/4.0/'] )

      library_scope = Work.where(published: true).
      where("json_attributes -> 'department' ?| array[:depts  ]", depts:   ['Library'] ).
      where("json_attributes -> 'format'     ?| array[:formats]", formats: ['image'] ).
      where("json_attributes -> 'rights'     ?| array[:rights ]", rights:  ['http://creativecommons.org/publicdomain/mark/1.0/'] )

      museum_scope.or(library_scope)
    end

    # TODO memoize this.
    def self.creator_categories
      creator = %w{ artist author creator_of_work interviewee interviewer photographer }
      publisher = [ 'publisher' ]
      contributor =  (Work::Creator::CATEGORY_VALUES - publisher) - creator
      {
        creator:     creator,
        publisher:   publisher,
        contributor: contributor
      }
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


    # Returns a hash of filenames and downloadable files:
    # file_hash.each { |filename, downloadable_file| [...] }
    def file_hash
      @file_hash ||= begin
        result = {}
        @scope.each do |work|
          result.merge!(WorkSerializer.file_hash(work))
        end
        result
      end
    end


    def title_row
      # if a given attribute stretches over several columns, label the columns correctly (creator#0, creator#1, creator#2, etc.)
      @attribute_keys.map do |k|
        if array_attributes.include? k.to_s
          raise "Unable to calculate column counts for #{k}" if column_counts[k.to_s].nil?
          (0..(column_counts[k.to_s] - 1)).map do |i|
            "#{ all_attributes[k ]}##{ i }"
           end
        else
          all_attributes[k]
        end
      end.flatten
    end

    # We store multiple values for each of these types of metadata.
    def array_attributes
      [
        'additional_title',
        'addressee',
        'after',
        'artist',
        'attributed_to',
        'author',
        'contributor',
        'creator',
        'engraver',
        'extent',
        'external_id',
        'format',
        'genre',
        'interviewee',
        'interviewer',
        'manner_of',
        'manufacturer',
        'medium',
        'photographer',
        'place',
        'printer',
        'printer_of_plates',
        'publisher',
        'school_of',
        'sponsor',
        'subject',
      ]
    end


    def creator_attributes
      @creator_attributes ||= self.class.creator_categories.map{|c, v| v}.flatten.sort
    end

    def non_creator_attributes
      @non_creator_attributes ||= array_attributes - creator_attributes
    end


    # Count of columns we need for each array attribute.
    def column_counts
      # how many columns do we need for each non-creator attribute?
      non_creator_column_counts = column_count_sql(
        non_creator_attributes,
        :column_max_arel
      )

      # how many columns do we need for each creator attribute?
      creator_column_counts = column_count_sql(
        creator_attributes,
        :creator_column_max_arel
      )
      Hash[ non_creator_column_counts.concat(creator_column_counts) ]
    end

    # Given a series of attributes, plucks arbitrary info from the scope about those attributes.
    # Pass in any method column_arel_method .
    def column_count_sql(attributes, column_arel_method)
      attributes.zip(
        @scope.pluck(
            *attributes.map { |c| self.send(column_arel_method, c) }
        ).first
      )
    end

    # sql to determine the maximum number of columns needed for a multiple-column attribute
    def column_max_arel(attribute_name)
      Arel.sql("max(jsonb_array_length(kithe_models.json_attributes -> '#{attribute_name}'))" )
    end

    # similar to column_max_arel above, but filters
    # creators by their category.
    #
    # Given a creator category (like "sponsor")
    # returns the max number of columns needed
    # for that category of creators.
    #
    # Makes use of some obscure JSONPath:
    #
    # $[*] ? (@.category == "sponsor")
    #
    # means “Take the root array $ (of creators),
    #   iterate over all elements $[*],
    #   and return only those objects $[*] ? whose
    #   category field is 'sponsor'.”
    def creator_column_max_arel(creator_category)
      Arel.sql(
        """
          max(
            jsonb_array_length(
              jsonb_path_query_array(
                kithe_models.json_attributes -> 'creator',
                '$[*] ? (@.category == \"#{creator_category}\")'
              )
            )
          )
        """
      )
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

        creator:                  'creator',

        contributor:              'contributor',

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

        # More specific creator metadata (these are also lumped together under "creator" above).
        artist:                    'customtext:artist',
        author:                    'customtext:author',
        interviewee:               'customtext:interviewee',
        interviewer:               'customtext:interviewer',
        photographer:              'customtext:photographer',

        # More specific creator metadata (these are also lumped together under "contributor" above).
        addressee:                  'customtext:addressee',
        after:                      'customtext:after',
        attributed_to:              'customtext:attributed_to',
        engraver:                   'customtext:engraver',
        manufacturer:               'customtext:manufacturer',
        manner_of:                  'customtext:manner_of',
        printer:                    'customtext:printer',
        printer_of_plates:          'customtext:printer_of_plates',
        school_of:                  'customtext:school_of',
        sponsor:                    'customtext:sponsor',


      }
    end
  end
end