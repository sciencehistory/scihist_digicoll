class AddAvailableByRequestModeToOralHistoryContent < ActiveRecord::Migration[6.0]
  def change
    create_enum :available_by_request_mode_type, %w[off automatic manual_review]

    add_column :oral_history_content, :available_by_request_mode, :enum, enum_type: :available_by_request_mode_type, null: false, default: "off"
  end
end
