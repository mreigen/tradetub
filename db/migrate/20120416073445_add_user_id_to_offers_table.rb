class AddUserIdToOffersTable < ActiveRecord::Migration
  def self.up
    add_column :offers, :user_id, :string, :default => "", :null => false
  end

  def self.down
    remove_column :offers, :user_id
  end
end
