class DropTableCreateOffersItemsTable < ActiveRecord::Migration
  def self.up
    drop_table :offers_items
  end

  def self.down
  end
end
