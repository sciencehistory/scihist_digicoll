class AddUniquenessConstraintToCartItem < ActiveRecord::Migration[8.0]
  def change
    add_index :cart_items, [:user_id, :work_id], unique: true
  end
end
