class RemoveRelatedUrlOpac < ActiveRecord::Migration[6.1]
  def change
    Rake::Task['scihist:data_fixes:remove_related_url_opac'].invoke
  end
end
