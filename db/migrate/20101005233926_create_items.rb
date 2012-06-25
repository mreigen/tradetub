class CreateItems < ActiveRecord::Migration
  def self.up
    create_table :items do |t|
      t.string :title
      t.text :description
      t.integer :user_id
      t.decimal :price, :precision => 8, :scale => 2
      t.boolean :featured
      t.date :available_on
      t.timestamps
    end
    add_index :items, :featured
    add_index :items, :available_on
  end

  def self.down
    drop_table :items
  end
end
