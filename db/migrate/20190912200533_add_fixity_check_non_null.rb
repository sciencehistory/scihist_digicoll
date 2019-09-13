class AddFixityCheckNonNull < ActiveRecord::Migration[5.2]
  def up
    change_column_null :fixity_checks, :actual_result, false, "[missing]"
    change_column_null :fixity_checks, :expected_result, false, "[missing]"
    change_column_null :fixity_checks, :hash_function, false, "[missing]"
    change_column_null :fixity_checks, :checked_uri, false, "[missing]"
    change_column_null :fixity_checks, :passed, false, false
  end

  def down
    change_column_null :fixity_checks, :passed, true
    change_column_null :fixity_checks, :checked_uri, true
    change_column_null :fixity_checks, :hash_function, true
    change_column_null :fixity_checks, :expected_result, true
    change_column_null :fixity_checks, :actual_result, true
  end
end
