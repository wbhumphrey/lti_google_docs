# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20140922203751) do

  create_table "canvas_tools", force: true do |t|
    t.text     "labid"
    t.text     "canvas_tool_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "clients", force: true do |t|
    t.string   "client_name"
    t.string   "canvas_url"
    t.string   "canvas_clientid"
    t.string   "canvas_client_secret"
    t.string   "contact_email"
    t.string   "client_id"
    t.string   "client_secret"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "lti_access_token"
  end

  create_table "courses", force: true do |t|
    t.text     "client_id"
    t.text     "canvas_course_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "canvas_module_id"
  end

  create_table "lab_instances", force: true do |t|
    t.string   "labid"
    t.string   "studentid"
    t.string   "fileid"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "labs", force: true do |t|
    t.string   "title"
    t.string   "folderName"
    t.string   "folderId"
    t.string   "participation"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "course_id"
  end

  create_table "lti_google_docs_canvas_google_user_bridges", force: true do |t|
    t.string   "userid"
    t.string   "refresh_token"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "lti_google_docs_users", force: true do |t|
    t.string   "userid"
    t.string   "refresh"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "share_requests", force: true do |t|
    t.string   "creator"
    t.string   "for"
    t.string   "file_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", force: true do |t|
    t.string   "canvas_user_id"
    t.string   "refresh"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "email"
    t.string   "google_access_token"
    t.string   "canvas_access_token"
    t.string   "api_token"
  end

end
