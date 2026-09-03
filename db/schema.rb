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

ActiveRecord::Schema[8.1].define(version: 2026_09_03_211015) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "decisions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "decision_type", null: false
    t.text "reason", null: false
    t.bigint "request_id", null: false
    t.datetime "updated_at", null: false
    t.index ["request_id"], name: "index_decisions_on_request_id"
    t.check_constraint "decision_type::text = ANY (ARRAY['accepted'::character varying::text, 'deferred'::character varying::text, 'declined'::character varying::text])", name: "decisions_decision_type_check"
  end

  create_table "requests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "expected_impact", null: false
    t.string "organization", null: false
    t.text "problem_statement", null: false
    t.string "status", default: "pending", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "urgency", null: false
    t.index ["status"], name: "index_requests_on_status"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'accepted'::character varying::text, 'deferred'::character varying::text, 'declined'::character varying::text])", name: "requests_status_check"
    t.check_constraint "urgency::text = ANY (ARRAY['low'::character varying::text, 'medium'::character varying::text, 'high'::character varying::text])", name: "requests_urgency_check"
  end

  add_foreign_key "decisions", "requests"
end
