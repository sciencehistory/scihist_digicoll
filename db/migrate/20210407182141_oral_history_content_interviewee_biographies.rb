class OralHistoryContentIntervieweeBiographies < ActiveRecord::Migration[6.1]
  def change
    create_join_table :oral_history_content, :interviewee_biographies do |t|
      t.index :oral_history_content_id, name: "index_interviewee_biographies_oral_history_content_oh"
      t.index :interviewee_biography_id, name: "index_interviewee_biographies_oral_history_content_bio"
    end
  end
end
