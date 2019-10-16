class ConvertAdminNotesFromStringToArray < ActiveRecord::Migration[5.2]
  def change
    # Keep Solr indexing from happening, cause that causes n+1 queries and general slowdown
    Kithe.indexable_settings.disable_callbacks = true
    Work.transaction do
      Work.where("jsonb_typeof(json_attributes -> 'admin_note') = 'string'").find_each do |work|
         # Rails doens’t realize it’s changed otherwise,
         # since it kind of hasn’t to Rails
         work.json_attributes_will_change!
         work.save! # should save in new array form now
      end
    end
  end
end
