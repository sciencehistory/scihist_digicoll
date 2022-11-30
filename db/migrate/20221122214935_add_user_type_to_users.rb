class AddUserTypeToUsers < ActiveRecord::Migration[6.1]
  # This user_type column will eventually allow us to have more than
  # two user types. See https://github.com/sciencehistory/scihist_digicoll/issues/1948
  def change
    add_column :users, :user_type, :string, default: 'editor'
  end
end
