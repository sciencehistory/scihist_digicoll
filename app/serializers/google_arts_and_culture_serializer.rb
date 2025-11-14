# The serializer will use these associations, so they should be eager-loaded:
# * leaf_representative
#
# serializer = WorkCartSerializer.new(columns)


# Next steps- try and do this on Thursday
  # Deal with the filenames
  # Create a zip file with all the filenames and the metadata.
  # Test the thing in a real google spreadsheet and see if it imports.

class GoogleArtsAndCultureSerializer

  def initialize(scope, columns: nil)
    @scope = scope
    @column_keys = if columns.nil?
      all_columns.keys
    else
      columns.select { |c| all_columns.keys.include? c }
    end
  end


  # Does not close the tempfile - that's your responsibility.
  def csv_tempfile
    output_csv_file = Tempfile.new
    CSV.open(output_csv_file, "wb") do |csv|
      self.to_a.each { |row| csv << row }
    end
    output_csv_file
  end

  def to_a
    data = []
    data << title_row
    @scope.includes(:leaf_representative).find_each do |work|
      data << work_row(work)
      assets = GoogleArtsAndCultureZipCreator.members_to_include(work)
      assets.each do |asset|
         data << asset_row(asset)
      end
    end
    data
  end

  # number of columns we need for each array column.
  def column_counts
    @column_counts ||= Hash[
        array_columns.zip(
        @scope.pluck(
            *array_columns.map { |c| column_max_arel c }
        ).first
      )
    ]
  end

  def column_max_arel(column_name)
    #pp Arel.sql("max(jsonb_array_length(kithe_models.json_attributes -> '#{column_name}'))" )
    Arel.sql("max(jsonb_array_length(kithe_models.json_attributes -> '#{column_name}'))" )
  end

  def title_row
    @column_keys.map do |k|
      if array_columns.include? k.to_s
        #pp "column count for #{k}: #{column_counts[k.to_s]}"
        (0..(column_counts[k.to_s] - 1)).map do |i|
          "#{k}##{i}"
         end
      else
        all_columns[k]
      end
    end.flatten
  end

  def work_row(work)
    @column_keys.map do |k|
      scalar_or_array(
        column_methods[k].call(work), column_counts.dig(k.to_s)
      )
    end.flatten
  end


  def filename_from_asset(asset)
    if asset&.file&.url.nil?
      no_value
    else
      File.basename(URI.parse(asset.file.url(public: true)))
    end
  end

  def asset_row(asset)
    filename = if asset&.file&.url.nil?
      no_value
    else
      GoogleArtsAndCultureZipCreator.filename_from_asset(asset)
    end

    vals = {
      friendlier_id:  not_applicable, # this is just for works
      subitem_id:     asset.friendlier_id,
      order_id:       asset.position || no_value,
      title:          asset.title,
      filespec:       filename,
    }

      # filetype    # "Image",  "Video", or "Sequence"
      # sequence if moer than one image in.
      # For now works with one image are treated as one-item "sequence."

      # filespec  # the name of the file (should be unique)


    @column_keys.map do |k|
      count = column_counts.dig(k.to_s)
      if count.nil?
        vals.fetch(k, not_applicable)
      else
        Array.new(count, not_applicable)
      end
    end.flatten

  end

  # A hash of possible columns (and their titles)
  # you can use in the report.
  # By default, the report contains all these columns,
  # but you can pass `columns` to return fewer.
  def all_columns
    @all_columns ||= {
      friendlier_id:            'itemid',       # friendlier_id of works
      subitem_id:               'subitemid',    # friendlier_id of assets
      order_id:                 'orderid',      # order
      title:                    'title',
      filespec:                 'filespec',
      url:                      'relation:url',

      # additional_title:         'additional_title',
      # creator:                  'creator',
      # department:               'department',

      # # filetype    # "Image",  "Video", or "Sequence"
      # # sequence if moer than one image in.
      # # For now works with one image are treated as one-item "sequence."

      # # filespec  # the name of the file (should be unique)
      # min_date:                 'dateCreated:start',
      # max_date:                 'dateCreated:end',
      # date_of_work:             'dateCreated:display',


      # medium:                   'medium',
      # extent:                   'Extent',
      # place:                    'locationCreated:placename',
      # format:                   'format',
      # genre:                    'genre',
      # description:              'description',
      subject:                    'subject',
      # rights_holder:            'rights',

    }
  end


  def array_columns
    [
      'subject',
      'external_id',
      'additional_title',
      'genre',
      'date_of_work',
      'creator',
      'medium',
      'extent',
      'place',
      'format',
    ]
  end


  # Returns a hash.
  # The keys of the hash are the same as @column_keys .
  # The values of the hash are procs.
  #
  # Each proc
  #   takes the work as an argument and
  #   returns the metadata we want.
  #
  # { :title => method(work), :additional_title => method(work), ... }
  def column_methods
    @column_methods ||= @column_keys.map do |column_label|
    
      # create the proc
      new_proc = if self.respond_to? column_label
        # If k is defined in this class, use that (e.g. :created)
        Proc.new { |some_work| self.send column_label, some_work }
      elsif Work.method_defined? column_label
        # Or, if k is defined as a method on work, use that (e.g. :title)
        Proc.new { |some_work| some_work.send column_label }
      else
        raise "Unknown column: #{column_label}"
      end
    
      [column_label, new_proc]
    end.to_h
  end

  def scalar_or_array(arr_or_string, count_of_columns_needed)
    return no_value if arr_or_string.nil?

    return arr_or_string if arr_or_string.is_a? String

    if arr_or_string.length > count_of_columns_needed
      raise "Too many values"
    else
      pad_array(arr_or_string, count_of_columns_needed, padding)
    end
  end


  def pad_array(array, target_length, padding_value = nil)
    return array if array.length == target_length
    array.concat(Array.new(target_length - array.length, padding_value))
  end


  # START WORK METHODS:
  def subitem_id(work)
    not_applicable
  end

  # Should we treat works with only one asset differently? Probably not.
  def filespec(work)
    not_applicable
  end

  def order_id(work)
    not_applicable
  end

  def url(work)
    work.url
  end

  def external_id(work)
    work.external_id.map(&:value)
  end

  def creator(work)
    work.creator.map(&:value)
  end

  def place(work)
    work.place.map(&:value)
  end

  def collection(work)
    work.contained_by.map(&:title)
  end

  def date_of_work(work)
    DateDisplayFormatter.new(work.date_of_work).display_dates
  end

  def min_date(work)
    DateIndexHelper.new(work).min_date&.in_time_zone("UTC")&.xmlschema
  end

  def max_date(work)
    DateIndexHelper.new(work).max_date&.in_time_zone("UTC")&.xmlschema
  end

  def description(work)
    DescriptionDisplayFormatter.new(work.description).format_plain
  end

  def physical_container(work)
    return no_value if work.physical_container.nil?
    work.physical_container.attributes.map {|l, v | "#{l.humanize}: #{v}" if v.present? }.compact
  end

  def additional_credit(work)
     work.additional_credit.map{ |item| "#{item.role}:#{item.name}" }
  end

  def created(work)
    I18n.l work.created_at, format: :admin
  end

  def last_modified(work)
    I18n.l work.updated_at, format: :admin
  end

  def url(work)
  end

  # END WORK METHODS



  protected

  def app_url_base
    @app_url_base ||= ScihistDigicoll::Env.lookup!(:app_url_base)
  end

  def test_mode
    true
  end

  def padding
    test_mode ? 'PADDING' : ''
  end

  def no_value
    test_mode ? 'NO_VALUE' : ''
  end

  def not_applicable
    test_mode ? 'N/A' : ''
  end


end
