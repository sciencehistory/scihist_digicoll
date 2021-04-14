class CreateIntervieweeBiographies < ActiveRecord::Migration[6.1]
  def change
    create_table :interviewee_biographies do |t|
      t.string :name, null: false
      t.jsonb :json_attributes

      t.timestamps
    end
  end
end
