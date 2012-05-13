class CreateOffersTable < ActiveRecord::Migration
  def self.up
    create_table :offers do |t|
      t.string :sender_id, :null => false
      t.string :sender_product_id, :null => false
      t.string :offer_item_id, :null => false
      t.timestamps
    end
  end

  def self.down
    drop_table :offers
  end
end
