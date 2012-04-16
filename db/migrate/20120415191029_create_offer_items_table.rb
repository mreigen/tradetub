class CreateOfferItemsTable < ActiveRecord::Migration
  def self.up
    create_table :offer_items do |t|
      t.string :product_id
      t.string :product_wanted_id
    end
  end

  def self.down
    drop_table :offer_items
  end
end
