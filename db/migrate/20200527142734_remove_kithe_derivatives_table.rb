class RemoveKitheDerivativesTable < ActiveRecord::Migration[6.0]
  def change
    drop_table :kithe_derivatives
  end
end
