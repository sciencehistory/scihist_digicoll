module GoogleArtsAndCulture
  class GoogleArtsAndCulture::WorkSerializer < GoogleArtsAndCulture::KitheModelSerializer


    def self.members_to_include(work)
      work.members.
        includes(:leaf_representative).
        where(published: true).
        where(type: "Asset").
        order(:position).
        select do |m|
          m.leaf_representative.content_type == "image/jpeg" || m.leaf_representative&.file_derivatives(:download_full)
        end
    end

    # Returns a hash of { filename_string => file_obj }
    def self.file_hash(work)
      self.members_to_include(work).map do |asset|
        [GoogleArtsAndCulture::AssetSerializer.filename(asset), GoogleArtsAndCulture::AssetSerializer.file(asset)]
      end.to_h
    end



    def initialize(model, callback: nil, attribute_keys:, column_counts:)
      super
      @work = model
    end

    def members_to_include
      @members_to_include ||= self.class.members_to_include(@work)
    end

    def file_hash
      @file_hash ||= self.class.file_hash(@work)
    end


    def metadata
      result = [work_metadata]
      unless single_member?
        members_to_include.each do |member|
          result << GoogleArtsAndCulture::AssetSerializer.new(member, attribute_keys: @attribute_keys, column_counts: @column_counts).metadata
        end
      end
      result
    end


    def work_metadata
      @attribute_keys.map do |key|
        scalar_or_padded_array(
          work_attribute_methods[key].call,
          count_of_columns_needed: @column_counts.dig(key.to_s)
        )
      end.flatten
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
      tmp = @attribute_keys.map do |attribute_label|
        new_proc = if self.respond_to? attribute_label
          # If k is defined in this class, use that (e.g. :created)
          Proc.new { self.send attribute_label }
        elsif Work.method_defined? attribute_label
          # Or, if k is defined as a method on work, use that (e.g. :title)
          Proc.new { @work.send attribute_label }
        else
          raise "Unknown column: #{attribute_label}"
        end
        [attribute_label, new_proc]
      end.to_h

      if single_member?
        asset_serializer = GoogleArtsAndCulture::AssetSerializer.new(members_to_include.first, attribute_keys: @attribute_keys, column_counts: @column_counts)
        tmp[:filetype] =  Proc.new { asset_serializer.send(:filetype) } 
        tmp[:file_name] = Proc.new { asset_serializer.send(:filename) } 
      end

      tmp
    end


    def single_member?
      @single_member ||= members_to_include.count == 1
    end


    def filetype
      'Sequence'
    end

    def file_name
      not_applicable
    end

    def subitem_id
      not_applicable
    end

    def order_id
      not_applicable
    end

    def url_text
      'Science History Institute Digital Collections'
    end

    def url
      app_url_base + Rails.application.routes.url_helpers.work_path(@work.friendlier_id)
    end

    def app_url_base
      @app_url_base ||= ScihistDigicoll::Env.lookup!(:app_url_base)
    end

    def external_id
      @work.external_id.map(&:value)
    end

    # Creator methods
    def creator
      sorted_creators[:creators].map(&:value)
    end

    # These values are also included in "creator" but also get their own customtext column
    # (e.g. customtext:artist)
    # Otherwise there's no way of knowing, for instance,
    # that a particular person or organization was the artist (as opposed to the author)
    # of a given work, as everything is lumped into #creator .
    [
      'artist',
      'author',
      'creator_of_work',
      'interviewee',
      'interviewer',
      'photographer'

    ].each do |creator_category|
      define_method(creator_category) do
        @work.creator.find_all { |creator| creator.category == creator_category }.map(&:value)
      end
    end

    def publisher
      sorted_creators[:publishers].map(&:value)
    end

    def contributor
      sorted_creators[:contributors].map(&:value)
    end

    # Contributor methods
    # These values are also included in "contributor" but also
    # get their own customtext column (e.g. customtext:school_of)
    [
      'addressee',
      'after',
      'attributed_to',
      'engraver',
      'manner_of',
      'manufacturer',
      'printer',
      'printer_of_plates',
      'school_of',
      'sponsor'
    ].each do |creator_category|
      define_method(creator_category) do
        @work.creator.find_all { |creator| creator.category == creator_category }.map(&:value)
      end
    end


    def place
      @work.place.map(&:value)
    end


    def date_of_work
      unless min_date.present?
        no_value
      else
        DateDisplayFormatter.new(@work.date_of_work).display_dates.join("; ")
      end
    end

    def min_date
      @min_date ||= DateIndexHelper.new(@work).min_date.to_s
    end

    def max_date
      @max_date ||= DateIndexHelper.new(@work).max_date.to_s
    end

    def format_date
      date.year.to_s
    end

    def description
      DescriptionDisplayFormatter.new(@work.description).format_plain
    end

    def physical_container
      return no_value if @work.physical_container.nil?
      @work.physical_container.attributes.map {|l, v | "#{l.humanize}: #{v}" if v.present? }.compact
    end

    def additional_credit
       @work.additional_credit.map{ |item| "#{item.role}:#{item.name}" }
    end

    def created
      I18n.l @work.created_at, format: :admin
    end

    def last_modified
      I18n.l @work.updated_at, format: :admin
    end

    def rights
      RightsTerm.label_for(@work.rights)
    end

    def sorted_creators
      @sorted_creators ||= begin
        categories = GoogleArtsAndCulture::Exporter.creator_categories
        {
          creators: @work.creator.find_all { |creator| categories[:creator].include? creator.category },
          publishers: @work.creator.find_all { |creator| categories[:publisher].include? creator.category },
          contributors: @work.creator.find_all { |creator| categories[:contributor].include? creator.category },
        }
      end
    end

  end
end