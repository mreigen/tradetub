class AddOfferIdToOfferItemsTable < ActiveRecord::Migration
  def self.up
    add_column :offer_items, :offer_id, :string, :default => "", :null => false
  end

  def self.down
    remove_column :offer_items, :offer_id
  end
end
