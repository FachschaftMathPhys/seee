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

ActiveRecord::Schema.define(version: 20130110093720) do

  create_table "c_pics", force: :cascade do |t|
    t.string   "basename",       limit: 255
    t.integer  "course_prof_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "source",         limit: 255
    t.text     "text"
    t.integer  "step"
  end

  create_table "course_profs", force: :cascade do |t|
    t.integer "course_id"
    t.integer "prof_id"
  end

  create_table "courses", force: :cascade do |t|
    t.integer  "term_id"
    t.string   "title",       limit: 255
    t.integer  "students"
    t.integer  "faculty_id"
    t.integer  "old_form_i"
    t.string   "evaluator",   limit: 255
    t.string   "description", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "summary"
    t.string   "fscontact",   limit: 255
    t.integer  "form_id"
    t.string   "language",    limit: 255
    t.text     "note"
    t.string   "mails_sent",  limit: 255
  end

  create_table "faculties", force: :cascade do |t|
    t.string   "longname",   limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "shortname",  limit: 255
  end

  create_table "forms", force: :cascade do |t|
    t.integer  "term_id"
    t.string   "name",       limit: 255
    t.text     "content"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "pics", force: :cascade do |t|
    t.integer  "tutor_id"
    t.string   "basename",   limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "source",     limit: 255
    t.text     "text"
    t.integer  "step"
  end

  create_table "profs", force: :cascade do |t|
    t.string   "firstname",  limit: 255
    t.string   "surname",    limit: 255
    t.string   "email",      limit: 255
    t.integer  "gender"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "sessions", force: :cascade do |t|
    t.string   "ident",      limit: 255
    t.string   "cont",       limit: 255
    t.integer  "viewed_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "ip",         limit: 255
    t.string   "agent",      limit: 255
    t.string   "username",   limit: 255
  end

  create_table "terms", force: :cascade do |t|
    t.date     "firstday"
    t.date     "lastday"
    t.string   "title",      limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "critical"
    t.string   "longtitle",  limit: 255
  end

  create_table "tutors", force: :cascade do |t|
    t.integer  "course_id"
    t.string   "abbr_name",  limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "comment"
  end

end
