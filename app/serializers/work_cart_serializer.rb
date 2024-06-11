# Serializes one work to a hash, or a Tempfile.new containing CSV info
#
# The serializer will use these associations, so they should be eager-loaded:
# * leaf_representative
# * contained_by (collection)
#
# serializer = WorkCartSerializer.new(columns)
# serializer.row(work) # returns an array you can use in a report.

class WorkCartSerializer

  def initialize(scope, columns: nil, extra_separator: '|')
    @scope = scope
    @extra_separator = extra_separator
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
    @scope.includes(:leaf_representative, :contained_by).find_each do |work|
      data << row(work)
    end
    data
  end

  def title_row
    @column_keys.map {|k| all_columns[k]}
  end

  def row(work)
    @column_keys.map do |k|
      column_to_string(
        column_methods[k].call(work)
      )
    end
  end

  # A hash of possible columns (and their titles)
  # you can use in the report.
  # By default, the report contains all these columns,
  # but you can pass `columns` to return fewer.
  def all_columns
    @all_columns ||= {
      title:                    'Title',
      additional_title:         'Additional title',
      url:                      'URL',
      external_id:              'External ID',
      department:               'Department',
      creator:                  'Creator',
      date:                     'Date',
      medium:                   'Medium',
      extent:                   'Extent',
      place:                    'Place',
      genre:                    'Genre',
      description:              'Description',
      subject:                  'Subject/s',
      series_arrangement:       'Series Arrangement',
      physical_container:       'Physical Container',
      collection:               'Collection',
      rights:                   'Rights',
      rights_holder:            'Rights Holder',
      additional_credit:        'Additional Credit',
      digitization_funder:      'Digitization Funder',
      admin_note:               'Admin Note',
      created:                  'Created',
      last_modified:            'Last Modified'
    }
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

  def column_to_string(arr_or_string)
    return '' if arr_or_string.nil?
    return arr_or_string.join(@extra_separator) if arr_or_string.is_a?(Array)
    arr_or_string
  end

  def url(work)
    app_url_base + Rails.application.routes.url_helpers.work_path(work.friendlier_id)
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

  def date(work)
    DateDisplayFormatter.new(work.date_of_work).display_dates
  end

  def description(work)
    DescriptionDisplayFormatter.new(work.description).format_plain
  end

  def physical_container(work)
    return nil if work.physical_container.nil?
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

  protected

  def app_url_base
    @app_url_base ||= ScihistDigicoll::Env.lookup!(:app_url_base)
  end
end
