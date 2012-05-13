class AddCashValueToOffersTable < ActiveRecord::Migration
  def self.up
    add_column :offers, :cash_value, :decimal, :precision => 8, :scale => 2
  end

  def self.down
    remove_column :offers, :cash_value
  end
end
