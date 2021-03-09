class CreateAdminInterviewerProfiles < ActiveRecord::Migration[6.1]
  def change
    create_table :interviewer_profiles do |t|
      t.string :name
      t.text :profile

      t.timestamps
    end
  end
end
