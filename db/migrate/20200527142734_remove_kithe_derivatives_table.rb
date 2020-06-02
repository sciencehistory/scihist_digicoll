class RemoveKitheDerivativesTable < ActiveRecord::Migration[6.0]
  def change
    drop_table :kithe_derivatives do |t|
    end
  end
end
