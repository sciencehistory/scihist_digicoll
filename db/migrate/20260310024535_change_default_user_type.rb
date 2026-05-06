class ChangeDefaultUserType < ActiveRecord::Migration[8.0]
  def change
    change_column_default :users, :user_type, "basic_internal"
  end
end
