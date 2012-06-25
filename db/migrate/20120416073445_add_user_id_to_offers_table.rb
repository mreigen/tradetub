class AddUserIdToOffersTable < ActiveRecord::Migration
  def self.up
    add_column :offers, :user_id, :integer, :null => false, :default => 0
  end

  def self.down
    remove_column :offers, :user_id
  end
end
