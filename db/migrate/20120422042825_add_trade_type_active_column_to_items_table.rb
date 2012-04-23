class AddTradeTypeActiveColumnToItemsTable < ActiveRecord::Migration
  def self.up
    # 0 => both
    # 1 => cash only
    # 2 => trade only
    add_column :products, :trade_type, :tinyint, :default => 0
    add_column :products, :available, :boolean, :default => :true
  end

  def self.down
    remove_column :products, :trade_type
    remove_column :products, :available
  end
end
