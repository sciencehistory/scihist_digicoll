class GoogleArtsAndCultureSerializer
  include Rails.application.routes.url_helpers
  include GoogleArtsAndCultureSerializerHelper

  def initialize(scope, columns: nil)
    @scope = scope
    @attribute_keys = if columns.nil?
      all_attributes.keys
    else
      columns.select { |c| all_attributes.keys.include? c }
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
      assets = members_to_include(work)
      if assets.count == 1
        data << work_row(work, single_asset: assets.first)
      else 
        data << work_row(work)
        assets.each do |asset|
          data << asset_row(asset)
        end
      end
    end
    data
  end

  def title_row
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

  def work_row(work, single_asset: nil)
    @attribute_keys.map do |key|
      if single_asset.present? && key == :filetype
        asset_filetype(single_asset)
      elsif single_asset.present? && key == :file_name
        asset_filename(single_asset)
      else
        scalar_or_padded_array(
          work_attribute_methods[key].call(work),
          count_of_columns_needed: column_counts.dig(key.to_s)
        )
      end
    end.flatten
  end

  def asset_row(asset)
    vals = {
      file_name:      asset_filename(asset),
      filetype:       asset_filetype(asset),
      friendlier_id:  asset.parent.friendlier_id, # friendlier_id is just used for works
      subitem_id:     asset.friendlier_id,
      order_id:       asset.position || no_value,
      title:          asset.title,
    }

    @attribute_keys.map do |k|
      count = column_counts.dig(k.to_s)
      if count.nil?
        vals.fetch(k, not_applicable)
      else
        Array.new(count, not_applicable)
      end
    end.flatten
  end

  # number of columns we need for each array attribute.
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

  # A hash of possible columns (and their titles)
  # you can use in the report.
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


  # Returns a hash.
  # The keys of the hash are the same as @attribute_keys .
  # The values of the hash are procs.
  #
  # Each proc
  #   takes the work as an argument and
  #   returns the metadata we want.
  #
  # { :title => method(work), :additional_title => method(work), ... }
  def work_attribute_methods
    @work_attribute_methods ||= @attribute_keys.map do |attribute_label|
      new_proc = if self.respond_to? attribute_label
        # If k is defined in GoogleArtsAndCultureSerializerHelper, use that (e.g. :created)
        Proc.new { |some_work| self.send attribute_label, some_work }
      elsif Work.method_defined? attribute_label
        # Or, if k is defined as a method on work, use that (e.g. :title)
        Proc.new { |some_work| some_work.send attribute_label }
      else
        raise "Unknown column: #{attribute_label}"
      end
      [attribute_label, new_proc]
    end.to_h
  end

  def scalar_or_padded_array(arr_or_string, count_of_columns_needed: )
    return no_value if arr_or_string.nil?
    return arr_or_string if arr_or_string.is_a? String
    raise "Too many values" if arr_or_string.length > count_of_columns_needed
    return arr_or_string if arr_or_string.length == count_of_columns_needed
    arr_or_string.concat(Array.new(count_of_columns_needed - arr_or_string.length, padding))
  end

end
