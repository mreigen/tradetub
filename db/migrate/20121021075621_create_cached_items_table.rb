class CreateCachedItemsTable < ActiveRecord::Migration
  def self.up
    create_table :cached_items do |t|
      t.string :guid, :null => false, :primary => true, :unique => true
      t.string :title, :null => false
      t.text :description
      t.float :price, :null => false
      t.timestamp :posted_at
      t.string :url, :null => false
      t.string :source, :null => false
      t.float :lat, :default => 0
      t.float :lng, :default => 0
      t.string :zip, :default => "00000"
      t.string :image_original
      t.string :image_thumb
      t.string :image_medium
      t.string :email
      t.string :phone
      t.string :text
      
      t.timestamps
    end
  end

  def self.down
    drop_table :cached_items
  end
end
