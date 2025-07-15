# frozen_string_literal: true
class SearchBuilder
  # Applies a limit to search just within a given collection, filtering on solr
  # field where we've stored the containing collection ids.
  #
  # :collection_id needs to be provided in context, the actual UUID pk of collection,
  # since that's what we index.
  #
  # Used on CollectionShowController search within a collection
  class WithinCollectionBuilder < ::SearchBuilder
    class_attribute :collection_id_solr_field, default: "collection_id_ssim"
    class_attribute :box_id_solr_field,        default: "box_tsi"
    class_attribute :folder_id_solr_field,     default: "folder_tsi"

    self.default_processor_chain += [:within_collection]

    def within_collection(solr_parameters)
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << "{!term f=#{collection_id_solr_field}}#{collection_id}"
      solr_parameters[:fq] << "#{box_id_solr_field}:(#{box_id})" if box_id.present?
      solr_parameters[:fq] << "#{folder_id_solr_field}:(#{folder_id})" if folder_id.present?
    end

    private

    # Overrides CustomSortLogic#default_sort_order
    def default_sort_order
      scope.context.dig(:collection_default_sort_order) || super
    end

    def collection_id
      scope.context.fetch(:collection_id)
    end

    def box_id
      RSolr.solr_escape scope.context.fetch :box_id
    end

    def folder_id
      RSolr.solr_escape scope.context.fetch :folder_id
    end

  end
end
