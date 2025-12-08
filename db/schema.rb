# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_12_01_161421) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "vector"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "available_by_request_mode_type", ["off", "automatic", "manual_review"]

  create_function :kithe_models_friendlier_id_gen, sql_definition: <<-'SQL'
      CREATE OR REPLACE FUNCTION public.kithe_models_friendlier_id_gen(min_value bigint, max_value bigint)
       RETURNS text
       LANGUAGE plpgsql
      AS $function$
        DECLARE
          new_id_int bigint;
          new_id_str character varying := '';
          done bool;
          tries integer;
          alphabet char[] := ARRAY['0','1','2','3','4','5','6','7','8','9',
            'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',
            'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'];
          alphabet_length integer := array_length(alphabet, 1);

        BEGIN
          done := false;
          tries := 0;
          WHILE (NOT done) LOOP
            tries := tries + 1;
            IF (tries > 3) THEN
              RAISE 'Could not find non-conflicting friendlier_id in 3 tries';
            END IF;

            new_id_int := trunc(random() * (max_value - min_value) + min_value);

            -- convert bigint to a Base-36 alphanumeric string
            -- see https://web.archive.org/web/20130420084605/http://www.jamiebegin.com/base36-conversion-in-postgresql/
            -- https://gist.github.com/btbytes/7159902
            WHILE new_id_int != 0 LOOP
              new_id_str := alphabet[(new_id_int % alphabet_length)+1] || new_id_str;
              new_id_int := new_id_int / alphabet_length;
            END LOOP;

            done := NOT exists(SELECT 1 FROM kithe_models WHERE friendlier_id=new_id_str);
          END LOOP;
          RETURN new_id_str;
        END;
        $function$
  SQL

  create_table "active_encode_statuses", force: :cascade do |t|
    t.string "active_encode_id"
    t.uuid "asset_id"
    t.string "state"
    t.text "encode_error"
    t.integer "percent_complete"
    t.string "hls_master_playlist_s3_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_encode_id"], name: "index_active_encode_statuses_on_active_encode_id"
    t.index ["asset_id"], name: "index_active_encode_statuses_on_asset_id"
    t.index ["state"], name: "index_active_encode_statuses_on_state"
  end

  create_table "asset_derivative_storage_type_reports", force: :cascade do |t|
    t.jsonb "data_for_report", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "bot_challenged_requests", force: :cascade do |t|
    t.string "path"
    t.string "request_id"
    t.string "client_ip"
    t.string "user_agent"
    t.string "normalized_user_agent"
    t.jsonb "headers"
    t.datetime "created_at", null: false
    t.index ["client_ip"], name: "index_bot_challenged_requests_on_client_ip"
    t.index ["request_id"], name: "index_bot_challenged_requests_on_request_id"
  end

  create_table "cart_items", force: :cascade do |t|
    t.bigint "user_id"
    t.uuid "work_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["user_id", "work_id"], name: "index_cart_items_on_user_id_and_work_id", unique: true
    t.index ["user_id"], name: "index_cart_items_on_user_id"
    t.index ["work_id"], name: "index_cart_items_on_work_id"
  end

  create_table "digitization_queue_items", force: :cascade do |t|
    t.string "title"
    t.string "collecting_area"
    t.string "bib_number"
    t.string "location"
    t.string "accession_number"
    t.string "museum_object_id"
    t.string "box"
    t.string "folder"
    t.string "dimensions"
    t.text "scope"
    t.text "additional_notes"
    t.string "copyright_status"
    t.string "status", default: "awaiting_digitization"
    t.datetime "status_changed_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.date "deadline"
    t.boolean "is_digital_collections"
    t.boolean "is_rights_and_reproduction"
  end

  create_table "fixity_checks", force: :cascade do |t|
    t.uuid "asset_id", null: false
    t.boolean "passed", null: false
    t.string "expected_result", null: false
    t.string "actual_result", null: false
    t.string "checked_uri", null: false
    t.string "hash_function", default: "SHA-512", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["asset_id", "checked_uri"], name: "by_asset_and_checked_uri"
    t.index ["asset_id"], name: "index_fixity_checks_on_asset_id"
    t.index ["checked_uri"], name: "index_fixity_checks_on_checked_uri"
  end

  create_table "fixity_reports", force: :cascade do |t|
    t.jsonb "data_for_report", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "interviewee_biographies", force: :cascade do |t|
    t.string "name", null: false
    t.jsonb "json_attributes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "interviewee_biographies_oral_history_content", id: false, force: :cascade do |t|
    t.bigint "oral_history_content_id", null: false
    t.bigint "interviewee_biography_id", null: false
    t.index ["interviewee_biography_id"], name: "index_interviewee_biographies_oral_history_content_bio"
    t.index ["oral_history_content_id"], name: "index_interviewee_biographies_oral_history_content_oh"
  end

  create_table "interviewer_profiles", force: :cascade do |t|
    t.string "name"
    t.text "profile"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "interviewer_profiles_oral_history_content", id: false, force: :cascade do |t|
    t.bigint "oral_history_content_id", null: false
    t.bigint "interviewer_profile_id", null: false
  end

  create_table "kithe_model_contains", id: false, force: :cascade do |t|
    t.uuid "containee_id"
    t.uuid "container_id"
    t.index ["containee_id"], name: "index_kithe_model_contains_on_containee_id"
    t.index ["container_id"], name: "index_kithe_model_contains_on_container_id"
  end

  create_table "kithe_models", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "title", null: false
    t.string "type", null: false
    t.integer "position"
    t.jsonb "json_attributes"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.uuid "parent_id"
    t.string "friendlier_id", default: -> { "kithe_models_friendlier_id_gen('2176782336'::bigint, '78364164095'::bigint)" }, null: false
    t.jsonb "file_data"
    t.uuid "representative_id"
    t.uuid "leaf_representative_id"
    t.bigint "digitization_queue_item_id"
    t.boolean "published", default: false, null: false
    t.integer "kithe_model_type", null: false
    t.string "role"
    t.datetime "published_at", precision: nil
    t.jsonb "derived_metadata_jsonb"
    t.index ["file_data"], name: "index_kithe_models_on_file_data", using: :gin
    t.index ["friendlier_id"], name: "index_kithe_models_on_friendlier_id", unique: true
    t.index ["leaf_representative_id"], name: "index_kithe_models_on_leaf_representative_id"
    t.index ["parent_id"], name: "index_kithe_models_on_parent_id"
    t.index ["representative_id"], name: "index_kithe_models_on_representative_id"
  end

  create_table "on_demand_derivatives", force: :cascade do |t|
    t.uuid "work_id", null: false
    t.string "deriv_type", null: false
    t.string "status", default: "in_progress", null: false
    t.string "inputs_checksum", null: false
    t.text "error_info"
    t.integer "progress"
    t.integer "progress_total"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["work_id", "deriv_type"], name: "index_on_demand_derivatives_on_work_id_and_deriv_type", unique: true
    t.index ["work_id"], name: "index_on_demand_derivatives_on_work_id"
  end

  create_table "oral_history_access_requests", force: :cascade do |t|
    t.uuid "work_id", null: false
    t.text "patron_name_ciphertext"
    t.text "patron_institution_ciphertext"
    t.text "intended_use_ciphertext"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "delivery_status", default: "pending"
    t.bigint "oral_history_requester_email_id", null: false
    t.datetime "delivery_status_changed_at"
    t.text "notes_from_staff"
    t.index ["oral_history_requester_email_id"], name: "idx_on_oral_history_requester_email_id_ff2cc727ac"
    t.index ["work_id"], name: "index_oral_history_access_requests_on_work_id"
  end

  create_table "oral_history_ai_conversations", force: :cascade do |t|
    t.string "status", default: "queued", null: false
    t.uuid "external_id", default: -> { "gen_random_uuid()" }, null: false
    t.string "session_id"
    t.string "question", null: false
    t.vector "question_embedding", limit: 3072
    t.jsonb "response_metadata", default: {}
    t.jsonb "chunks_used", default: {}
    t.jsonb "error_info"
    t.jsonb "answer_json"
    t.datetime "request_sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "oral_history_chunks", force: :cascade do |t|
    t.vector "embedding", limit: 3072, null: false
    t.bigint "oral_history_content_id", null: false
    t.integer "start_paragraph_number", null: false
    t.integer "end_paragraph_number", null: false
    t.text "text", null: false
    t.string "speakers", default: [], array: true
    t.jsonb "other_metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "((embedding)::halfvec(3072)) halfvec_cosine_ops", name: "idx_on_embedding_halfvec_3072_halfvec_cosine_ops_4742ee9fb6", using: :hnsw
    t.index ["oral_history_content_id"], name: "index_oral_history_chunks_on_oral_history_content_id"
  end

  create_table "oral_history_content", force: :cascade do |t|
    t.uuid "work_id", null: false
    t.string "combined_audio_fingerprint"
    t.jsonb "combined_audio_component_metadata"
    t.text "ohms_xml_text"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "combined_audio_derivatives_job_status"
    t.datetime "combined_audio_derivatives_job_status_changed_at", precision: nil
    t.text "searchable_transcript_source"
    t.enum "available_by_request_mode", default: "off", null: false, enum_type: "available_by_request_mode_type"
    t.jsonb "json_attributes", default: {}
    t.jsonb "combined_audio_m4a_data"
    t.jsonb "input_docx_transcript_data"
    t.jsonb "output_sequenced_docx_transcript_data"
    t.index ["work_id"], name: "index_oral_history_content_on_work_id", unique: true
  end

  create_table "oral_history_requester_emails", force: :cascade do |t|
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_oral_history_requester_emails_on_email", unique: true
  end

  create_table "orphan_reports", force: :cascade do |t|
    t.jsonb "data_for_report", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "queue_item_comments", force: :cascade do |t|
    t.bigint "digitization_queue_item_id", null: false
    t.bigint "user_id"
    t.text "text"
    t.boolean "system_action"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["digitization_queue_item_id"], name: "index_queue_item_comments_on_digitization_queue_item_id"
    t.index ["user_id"], name: "index_queue_item_comments_on_user_id"
  end

  create_table "scheduled_ingest_bucket_deletions", force: :cascade do |t|
    t.string "path"
    t.datetime "delete_after", precision: nil
    t.uuid "asset_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id"], name: "index_scheduled_ingest_bucket_deletions_on_asset_id"
  end

  create_table "searches", id: :serial, force: :cascade do |t|
    t.binary "query_params"
    t.integer "user_id"
    t.string "user_type"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["user_id"], name: "index_searches_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "name"
    t.boolean "locked_out"
    t.string "user_type", default: "editor"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "fixity_checks", "kithe_models", column: "asset_id"
  add_foreign_key "kithe_model_contains", "kithe_models", column: "containee_id"
  add_foreign_key "kithe_model_contains", "kithe_models", column: "container_id"
  add_foreign_key "kithe_models", "digitization_queue_items"
  add_foreign_key "kithe_models", "kithe_models", column: "leaf_representative_id"
  add_foreign_key "kithe_models", "kithe_models", column: "parent_id"
  add_foreign_key "kithe_models", "kithe_models", column: "representative_id"
  add_foreign_key "on_demand_derivatives", "kithe_models", column: "work_id"
  add_foreign_key "oral_history_access_requests", "kithe_models", column: "work_id"
  add_foreign_key "oral_history_access_requests", "oral_history_requester_emails"
  add_foreign_key "oral_history_chunks", "oral_history_content"
  add_foreign_key "oral_history_content", "kithe_models", column: "work_id"
  add_foreign_key "queue_item_comments", "digitization_queue_items"
end
