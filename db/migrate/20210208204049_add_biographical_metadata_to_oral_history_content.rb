class AddBiographicalMetadataToOralHistoryContent < ActiveRecord::Migration[6.1]
  def change
    add_column :oral_history_content, :IntervieweeDate, :jsonb # , null: false
    add_column :oral_history_content, :IntervieweeSchool, :jsonb # , null: false
    add_column :oral_history_content, :IntervieweeJob, :jsonb # , null: false
    add_column :oral_history_content, :IntervieweeHonor, :jsonb # , null: false
  end
end