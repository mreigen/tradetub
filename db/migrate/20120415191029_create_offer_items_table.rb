class CreateOfferItemsTable < ActiveRecord::Migration
  def self.up
    create_table :offer_items do |t|
      t.integer :item_id
      t.integer :product_wanted_id
    end
  end

  def self.down
    drop_table :offer_items
  end
end
