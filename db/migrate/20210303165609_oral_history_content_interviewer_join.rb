class OralHistoryContentInterviewerJoin < ActiveRecord::Migration[6.1]
  def change
    create_join_table :oral_history_content, :interviewer_profiles
  end
end
