# Just takes a list of works and does a kithe/traject solr reindex of them in a bg job,
# easy peasy!!
#
# Recommend you pass only a fairly small number per-job, perhaps
# `Kithe.indexable_settings.batching_mode_batch_size`
#
# If you pass in ID that doesn't exist, it will silently ignore it! This is intentional,
# in case the work was deleted after job was queued. But it is a potential silent error
# if you messed something up.
class ReindexWorksJob < ApplicationJob
  def perform(pk_array)
    Kithe::Indexable.index_with(batching: true) do
      Work.strict_loading.for_batch_indexing.where(id: pk_array).each do |w|
        w.update_index
      end
    end
  end
end
