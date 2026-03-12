class UserLockedOutDefaultFalse < ActiveRecord::Migration[8.0]
  def change
    change_column_default :users, :locked_out, false
  end
end
