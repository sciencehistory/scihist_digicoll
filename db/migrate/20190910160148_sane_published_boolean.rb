# https://thoughtbot.com/blog/avoid-the-threestate-boolean-problem
# Make pubilished column default false and not accept null
class SanePublishedBoolean < ActiveRecord::Migration[5.2]
  def up
    change_column_default :kithe_models, :published, false
    change_column_null :kithe_models, :published, false, false
  end
  def down
   change_column_default :kithe_models, :published, nil
   change_column_null :kithe_models, :published, true
  end
end
