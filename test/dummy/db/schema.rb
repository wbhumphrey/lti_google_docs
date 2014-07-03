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

ActiveRecord::Schema.define(version: 20140703172919) do

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
    t.string   "userid"
    t.string   "refresh"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "email"
  end

end
