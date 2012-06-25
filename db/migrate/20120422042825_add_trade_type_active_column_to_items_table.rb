class AddTradeTypeActiveColumnToItemsTable < ActiveRecord::Migration
  def self.up
    # 0 => both
    # 1 => cash only
    # 2 => trade only
    add_column :items, :trade_type, :integer, :default => 0
    add_column :items, :available, :boolean, :default => :true
  end

  def self.down
    remove_column :items, :trade_type
    remove_column :items, :available
  end
end
