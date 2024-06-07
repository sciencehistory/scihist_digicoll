# Serializes one work to a hash that can be used
# by CartExporter.
#
# The serializer will use these associations, so they should be eager-loaded:
# * leaf_representative
# * contained_by (collection)
#
# serializer = WorkCartSerializer.new(columns)
# serializer.row(work) # returns an array you can use in a report.

class WorkCartSerializer
  include Rails.application.routes.url_helpers

  # This is the "menu" of possible columns you can use in the report
  # The default is to use all of them.
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

  def initialize(columns: nil, extra_separator: nil)
    @extra_separator = extra_separator || '|'
    @column_keys = if columns.nil?
      all_columns.keys
    else
      columns.select { |c| all_columns.keys.include? c }
    end
  end

  def title_row
    @column_keys.map {|k| all_columns[k]}
  end

  # For each column, define a method that
  #   * takes the work as an argument and
  #   * returns what we want.
  def column_methods
    @column_methods ||= @column_keys.map do |k|
      closure = if self.respond_to? k
        # If k is defined in this class, use that (e.g. :created)
        Proc.new {|w| self.send k, w }
      elsif Work.method_defined? k
        # Or, if k is defined as a method on work, use that (e.g. :title)
        Proc.new {|w| w.send k }
      else
        raise "Unknown column: #{k}"
      end
      [k, closure]
    end.to_h
  end

  def array_to_string(arr_or_string)
    return '' if arr_or_string.nil?
    return arr_or_string.join(@extra_separator ) if arr_or_string.is_a?(Array)
    arr_or_string
  end


  def row(work)
    @column_keys.map do |k|
      array_to_string(column_methods[k].call(work))
    end
  end

  def app_url_base
    @app_url_base ||= ScihistDigicoll::Env.lookup!(:app_url_base)
  end

  def url(work)
    app_url_base + work_path(work.friendlier_id)
  end

  def collection(work)
    work.contained_by.map(&:title)
  end

  def external_id(work)
    work.external_id.map(&:value)
  end

  def creator(work)
    work.creator.map(&:value)
  end

  def date(work)
    DateDisplayFormatter.new(work.date_of_work).display_dates
  end

  def place(work)
    work.place.map(&:value)
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
end
