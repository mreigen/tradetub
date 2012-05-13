class CreateWantedItemsTable < ActiveRecord::Migration
  def self.up
    create_table :wanted_items do |t|
      t.string :product_id
      t.string :offer_id
    end
  end

  def self.down
    drop_table :wanted_items
  end
end
