class CreateOffersTable < ActiveRecord::Migration
  def self.up
    create_table :offers do |t|
      t.integer :sender_id, :default => 0, :null => false
      t.integer :sender_product_id, :default => 0, :null => false
      t.integer :offer_item_id, :default => 0, :null => false
      t.timestamps
    end
  end

  def self.down
    drop_table :offers
  end
end
