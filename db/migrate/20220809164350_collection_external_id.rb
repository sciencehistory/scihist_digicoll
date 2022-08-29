class CollectionExternalId < ActiveRecord::Migration[6.1]
  def change
    Rake::Task['scihist:data_fixes:migrate_collection_bib_ids'].invoke
  end
end
