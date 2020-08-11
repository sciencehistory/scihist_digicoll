# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_08_10_180533) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_enum :available_by_request_mode_type, [
    "off",
    "automatic",
    "manual_review",
  ]


  create_function :kithe_models_friendlier_id_gen, sql_definition: <<-SQL
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
  create_table "cart_items", force: :cascade do |t|
    t.bigint "user_id"
    t.uuid "work_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.string "materials"
    t.text "scope"
    t.text "instructions"
    t.text "additional_notes"
    t.string "copyright_status"
    t.string "status", default: "awaiting_dig_on_cart"
    t.datetime "status_changed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "r_and_r_item_id"
  end

  create_table "fixity_checks", force: :cascade do |t|
    t.uuid "asset_id", null: false
    t.boolean "passed", null: false
    t.string "expected_result", null: false
    t.string "actual_result", null: false
    t.string "checked_uri", null: false
    t.string "hash_function", default: "SHA-512", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id", "checked_uri"], name: "by_asset_and_checked_uri"
    t.index ["asset_id"], name: "index_fixity_checks_on_asset_id"
    t.index ["checked_uri"], name: "index_fixity_checks_on_checked_uri"
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "parent_id"
    t.string "friendlier_id", default: -> { "kithe_models_friendlier_id_gen('2176782336'::bigint, '78364164095'::bigint)" }, null: false
    t.jsonb "file_data"
    t.uuid "representative_id"
    t.uuid "leaf_representative_id"
    t.bigint "digitization_queue_item_id"
    t.boolean "published", default: false, null: false
    t.integer "kithe_model_type", null: false
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["work_id", "deriv_type"], name: "index_on_demand_derivatives_on_work_id_and_deriv_type", unique: true
    t.index ["work_id"], name: "index_on_demand_derivatives_on_work_id"
  end

  create_table "oral_history_content", force: :cascade do |t|
    t.uuid "work_id", null: false
    t.jsonb "combined_audio_mp3_data"
    t.jsonb "combined_audio_webm_data"
    t.string "combined_audio_fingerprint"
    t.jsonb "combined_audio_component_metadata"
    t.text "ohms_xml_text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "combined_audio_derivatives_job_status"
    t.datetime "combined_audio_derivatives_job_status_changed_at"
    t.text "searchable_transcript_source"
    t.enum "available_by_request_mode", default: "off", null: false, enum_name: "available_by_request_mode_type"
    t.index ["work_id"], name: "index_oral_history_content_on_work_id", unique: true
  end

  create_table "queue_item_comments", force: :cascade do |t|
    t.bigint "digitization_queue_item_id"
    t.bigint "user_id"
    t.text "text"
    t.boolean "system_action"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "r_and_r_item_id"
    t.index ["digitization_queue_item_id"], name: "index_queue_item_comments_on_digitization_queue_item_id"
    t.index ["user_id"], name: "index_queue_item_comments_on_user_id"
  end

  create_table "r_and_r_items", force: :cascade do |t|
    t.string "title"
    t.string "curator"
    t.string "collecting_area"
    t.string "bib_number"
    t.string "location"
    t.string "accession_number"
    t.string "museum_object_id"
    t.string "box"
    t.string "folder"
    t.string "dimensions"
    t.string "materials"
    t.string "copyright_status"
    t.boolean "is_destined_for_ingest"
    t.boolean "copyright_research_still_needed", default: true
    t.text "instructions"
    t.text "scope"
    t.text "additional_pages_to_ingest"
    t.text "additional_notes"
    t.string "status", default: "awaiting_dig_on_cart"
    t.datetime "status_changed_at"
    t.datetime "deadline"
    t.datetime "date_files_sent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "patron_name_ciphertext"
    t.text "patron_email_ciphertext"
  end

  create_table "searches", id: :serial, force: :cascade do |t|
    t.binary "query_params"
    t.integer "user_id"
    t.string "user_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_searches_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.boolean "admin"
    t.boolean "locked_out"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "digitization_queue_items", "r_and_r_items"
  add_foreign_key "fixity_checks", "kithe_models", column: "asset_id"
  add_foreign_key "kithe_model_contains", "kithe_models", column: "containee_id"
  add_foreign_key "kithe_model_contains", "kithe_models", column: "container_id"
  add_foreign_key "kithe_models", "digitization_queue_items"
  add_foreign_key "kithe_models", "kithe_models", column: "leaf_representative_id"
  add_foreign_key "kithe_models", "kithe_models", column: "parent_id"
  add_foreign_key "kithe_models", "kithe_models", column: "representative_id"
  add_foreign_key "on_demand_derivatives", "kithe_models", column: "work_id"
  add_foreign_key "oral_history_content", "kithe_models", column: "work_id"
  add_foreign_key "queue_item_comments", "digitization_queue_items"
  add_foreign_key "queue_item_comments", "r_and_r_items"
end
