class RemoveRelatedUrlProvenance < ActiveRecord::Migration[6.1]
  def change
    Rake::Task['scihist:data_fixes:remove_related_url_provenance_note'].invoke
  end
end
