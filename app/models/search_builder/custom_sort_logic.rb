class SearchBuilder
  module CustomSortLogic
    extend ActiveSupport::Concern

    # OVERRIDE this method from:
    # https://github.com/projectblacklight/blacklight/blob/v6.7.2/lib/blacklight/search_builder.rb#L224
    def sort
      # if no sort is specified by the user, and there's no search phrase
      if blacklight_params[:sort].blank? && blacklight_params[:q].blank?
        # use the default sort order from catalog controller
        @default_blank_query_sort ||= default_sort_order
      else
        super
      end
    end

    private

    # see also WithinCollectionBuilder#default_sort_order, which overrides this method
    def default_sort_order
      # look up the blank_query_default sort order in the catalog controller
      blacklight_config.sort_fields.values.find { |f| f.blank_query_default == true }.try(:sort) ||
        # or just use relevance
        blacklight_config.default_sort_field
    end

  end
end
