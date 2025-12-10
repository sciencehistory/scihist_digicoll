module GoogleArtsAndCulture
  class GoogleArtsAndCulture::WorkSerializer < GoogleArtsAndCulture::KitheModelSerializer


    def self.memmbers_to_include(work)
      work.members.
        includes(:leaf_representative).
        where(published: true).
        where(type: "Asset").
        order(:position).
        select do |m|
          m.leaf_representative.content_type == "image/jpeg" || m.leaf_representative&.file_derivatives(:download_full)
        end
    end


    def initialize(model, callback: nil, attribute_keys:, column_counts:)
      super
      @work = model
    end

    def members_to_include
      @members_to_include ||= self.class.memmbers_to_include(@work)
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
          #puts "We do respond to #{attribute_label}"
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

    def files
      members_to_include.map do |asset|
        [GoogleArtsAndCulture::AssetSerializer.filename(asset), GoogleArtsAndCulture::AssetSerializer.file(asset)]
      end
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

    def creator
      @work.creator.find_all { |creator| creator.category.to_s != "publisher" }.map(&:value)
    end

    def publisher
      @work.creator.find_all { |creator| creator.category.to_s == "publisher" }.map(&:value).join(", ")
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

  end
end