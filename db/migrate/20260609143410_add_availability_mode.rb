class AddAvailabilityMode < ActiveRecord::Migration[8.1]
  def change
    create_enum :oh_availability_mode_type, %w[direct automatic_request reviewed_request embargoed]

    add_column :oral_history_content, :availability_mode, :enum, enum_type: :oh_availability_mode_type, null: false, default: "direct"
  end
end
