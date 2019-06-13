class SearchBuilder
  module CustomSortLogic
    extend ActiveSupport::Concern

    # OVERRIDE this method from:
    # https://github.com/projectblacklight/blacklight/blob/v6.7.2/lib/blacklight/search_builder.rb#L224
    # To make relevance only default if there is a query parameter, otherwise it makes no sense.
    def sort
      if blacklight_params[:sort].blank? && blacklight_params[:q].blank?
        @default_blank_query_sort ||= (blacklight_config.sort_fields.values.find { |f| f.blank_query_default == true }.try(:sort)  || blacklight_config.default_sort_field )
      else
        super
      end
    end

  end
end
