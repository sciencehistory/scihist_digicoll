class AddPublishedAtToWorks < ActiveRecord::Migration[6.1]
  def change
    add_column :kithe_models, :published_at, :datetime
  end
end