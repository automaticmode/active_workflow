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

ActiveRecord::Schema.define(version: 2020_06_24_160036) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "agent_locks", force: :cascade do |t|
    t.integer "agent_id"
    t.datetime "locked_at"
    t.index ["agent_id"], name: "index_agent_locks_on_agent_id", unique: true
  end

  create_table "agent_logs", force: :cascade do |t|
    t.integer "agent_id", null: false
    t.text "message", null: false
    t.integer "level", default: 3, null: false
    t.integer "inbound_message_id"
    t.integer "outbound_message_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "agent_scheduled", force: :cascade do |t|
    t.integer "agent_id"
    t.index ["agent_id"], name: "index_agent_scheduled_on_agent_id", unique: true
  end

  create_table "agents", force: :cascade do |t|
    t.integer "user_id"
    t.text "options"
    t.string "type"
    t.string "name"
    t.string "schedule"
    t.integer "messages_count", default: 0, null: false
    t.datetime "last_check_at"
    t.datetime "last_receive_at"
    t.integer "last_checked_message_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "memory"
    t.datetime "last_web_request_at"
    t.integer "keep_messages_for", default: 0, null: false
    t.datetime "last_message_at"
    t.datetime "last_error_log_at"
    t.boolean "disabled", default: false, null: false
    t.integer "service_id"
    t.string "guid", null: false
    t.boolean "deactivated", default: false
    t.index ["disabled", "deactivated"], name: "index_agents_on_disabled_and_deactivated"
    t.index ["guid"], name: "index_agents_on_guid"
    t.index ["schedule"], name: "index_agents_on_schedule"
    t.index ["type"], name: "index_agents_on_type"
    t.index ["user_id", "created_at"], name: "index_agents_on_user_id_and_created_at"
  end

  create_table "control_links", force: :cascade do |t|
    t.integer "controller_id", null: false
    t.integer "control_target_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["control_target_id"], name: "index_control_links_on_control_target_id"
    t.index ["controller_id", "control_target_id"], name: "index_control_links_on_controller_id_and_control_target_id", unique: true
  end

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer "priority", default: 0
    t.integer "attempts", default: 0
    t.text "handler"
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "links", force: :cascade do |t|
    t.integer "source_id"
    t.integer "receiver_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "message_id_at_creation", default: 0, null: false
    t.index ["receiver_id", "source_id"], name: "index_links_on_receiver_id_and_source_id"
    t.index ["source_id", "receiver_id"], name: "index_links_on_source_id_and_receiver_id"
  end

  create_table "messages", force: :cascade do |t|
    t.integer "user_id"
    t.integer "agent_id"
    t.text "payload"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "expires_at"
    t.index ["agent_id", "created_at"], name: "index_messages_on_agent_id_and_created_at"
    t.index ["expires_at"], name: "index_messages_on_expires_at"
    t.index ["user_id", "created_at"], name: "index_messages_on_user_id_and_created_at"
  end

  create_table "services", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "provider", null: false
    t.string "name", null: false
    t.text "token", null: false
    t.text "secret"
    t.text "refresh_token"
    t.datetime "expires_at"
    t.boolean "global", default: false
    t.text "options"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "uid"
    t.index ["provider"], name: "index_services_on_provider"
    t.index ["uid"], name: "index_services_on_uid"
    t.index ["user_id", "global"], name: "index_services_on_user_id_and_global"
  end

  create_table "user_credentials", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "credential_name", null: false
    t.text "credential_value", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["user_id", "credential_name"], name: "index_user_credentials_on_user_id_and_credential_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "admin", default: false, null: false
    t.integer "failed_attempts", default: 0
    t.string "unlock_token"
    t.datetime "locked_at"
    t.string "username", null: false
    t.integer "workflow_count", default: 0, null: false
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.datetime "deactivated_at"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["deactivated_at"], name: "index_users_on_deactivated_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "workflow_memberships", force: :cascade do |t|
    t.integer "agent_id", null: false
    t.integer "workflow_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["agent_id"], name: "index_workflow_memberships_on_agent_id"
    t.index ["workflow_id"], name: "index_workflow_memberships_on_workflow_id"
  end

  create_table "workflows", force: :cascade do |t|
    t.string "name", null: false
    t.integer "user_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "description"
    t.string "guid", null: false
    t.string "tag_bg_color"
    t.string "tag_fg_color"
    t.string "icon"
    t.index ["user_id", "guid"], name: "index_workflows_on_user_id_and_guid", unique: true
  end

end
