class GoogleArtsAndCultureSerializer
  include Rails.application.routes.url_helpers
  include GoogleArtsAndCultureSerializerHelper

  def initialize(scope, columns: nil)
    @scope = scope
    @column_keys = if columns.nil?
      all_columns.keys
    else
      columns.select { |c| all_columns.keys.include? c }
    end
  end

  # Does not close the tempfile.
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
      assets = GoogleArtsAndCultureZipCreator.members_to_include(work)
      data << work_row(work)
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
    Arel.sql("max(jsonb_array_length(kithe_models.json_attributes -> '#{column_name}'))" )
  end

  def title_row
    @column_keys.map do |k|
      if array_columns.include? k.to_s
        (0..(column_counts[k.to_s] - 1)).map do |i|
          "#{all_columns[k]}##{i}"
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

  def asset_row(asset)
    filename = if asset&.file&.url.nil?
      no_value
    else
      GoogleArtsAndCultureZipCreator.filename_from_asset(asset)
    end


    vals = {
      friendlier_id:  asset.parent.friendlier_id, # this is just for works
      subitem_id:     asset.friendlier_id,
      order_id:       asset.position || no_value,
      title:          asset.title,
      filespec:       filename,
      filetype:       asset_filetype(asset)
    }
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
      filetype:                 'filetype',
      url_text:                 'relation:text',
      url:                      'relation:url',

      # TODO:
      # additional_title:         'additional_title',
      creator:                  'creator',
      publisher:                'publisher',


      min_date:                 'dateCreated:start',
      max_date:                 'dateCreated:end',
      date_of_work:             'dateCreated:display',

      # ?:  datePublished:end
      # ?:  datePublished:start

      medium:                   'medium',

      # 'format' is actually used to store our 'extent' metadata in GAC.
      extent:                   'format',
      
      place:                    'locationCreated:placename',
      
      # TODO: figure out what google calls these:
      # format:                   'format',
      # genre:                    'genre',
      description:              'description',
      subject:                    'subject',
      rights_holder:            'rights',

    }
  end


  def array_columns
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

  def app_url_base
    @app_url_base ||= ScihistDigicoll::Env.lookup!(:app_url_base)
  end

  def test_mode
    false
  end
end
