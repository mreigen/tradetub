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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 201204230143021) do

  create_table "active_admin_comments", :force => true do |t|
    t.integer  "resource_id",   :null => false
    t.string   "resource_type", :null => false
    t.integer  "author_id"
    t.string   "author_type"
    t.text     "body"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "namespace"
  end

  add_index "active_admin_comments", ["author_type", "author_id"], :name => "index_active_admin_comments_on_author_type_and_author_id"
  add_index "active_admin_comments", ["namespace"], :name => "index_active_admin_comments_on_namespace"
  add_index "active_admin_comments", ["resource_type", "resource_id"], :name => "index_admin_notes_on_resource_type_and_resource_id"

  create_table "categories", :force => true do |t|
    t.string   "fullname"
    t.string   "nickname"
    t.string   "uid"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "image_uploads", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "image_file_name"
    t.string   "image_content_type"
    t.integer  "image_file_size"
    t.datetime "image_updated_at"
    t.string   "product_id",         :default => "",    :null => false
    t.boolean  "is_main_image",      :default => false
  end

  create_table "line_items", :force => true do |t|
    t.integer  "order_id"
    t.integer  "product_id"
    t.decimal  "price"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "line_items", ["order_id"], :name => "index_line_items_on_order_id"
  add_index "line_items", ["product_id"], :name => "index_line_items_on_product_id"

  create_table "offer_items", :force => true do |t|
    t.string  "product_id"
    t.string  "offer_id",                                     :default => "", :null => false
    t.decimal "adjusted_price", :precision => 8, :scale => 2
  end

  create_table "offer_services", :force => true do |t|
    t.string "service_id"
    t.string "offer_id"
  end

  create_table "offers", :force => true do |t|
    t.string   "sender_id",                                                 :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "user_id",                                  :default => "",  :null => false
    t.decimal  "response",                                 :default => 0.0
    t.decimal  "cash_value", :precision => 8, :scale => 2
  end

  create_table "orders", :force => true do |t|
    t.integer  "user_id"
    t.datetime "checked_out_at"
    t.decimal  "total_price",    :precision => 8, :scale => 2, :default => 0.0
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "orders", ["checked_out_at"], :name => "index_orders_on_checked_out_at"
  add_index "orders", ["user_id"], :name => "index_orders_on_user_id"

  create_table "products", :force => true do |t|
    t.string   "title"
    t.text     "description"
    t.string   "user_id"
    t.decimal  "price"
    t.boolean  "featured"
    t.date     "available_on"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "image_file_name"
    t.string   "image_content_type"
    t.integer  "image_file_size"
    t.datetime "image_updated_at"
    t.string   "cat_id"
    t.integer  "trade_type",         :default => 0
    t.boolean  "available",          :default => true
  end

  add_index "products", ["available_on"], :name => "index_products_on_available_on"
  add_index "products", ["featured"], :name => "index_products_on_featured"

  create_table "ratings", :force => true do |t|
    t.string  "offer_id"
    t.integer "score"
    t.string  "comment"
  end

  create_table "services", :force => true do |t|
    t.string "name"
    t.string "service_type"
    t.string "user_id"
  end

  create_table "users", :force => true do |t|
    t.string   "email",                               :default => "", :null => false
    t.string   "encrypted_password",   :limit => 128, :default => "", :null => false
    t.string   "reset_password_token"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                       :default => 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "username",                            :default => "", :null => false
  end

  add_index "users", ["email"], :name => "index_admin_users_on_email", :unique => true
  add_index "users", ["reset_password_token"], :name => "index_admin_users_on_reset_password_token", :unique => true

  create_table "wanted_items", :force => true do |t|
    t.string  "product_id"
    t.string  "offer_id"
    t.decimal "adjusted_price", :precision => 8, :scale => 2
  end

  create_table "wanted_services", :force => true do |t|
    t.string "service_id"
    t.string "offer_id"
  end

end
