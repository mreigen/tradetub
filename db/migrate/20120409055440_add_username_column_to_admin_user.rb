class AddUsernameColumnToAdminUser < ActiveRecord::Migration
  def self.up
    add_column :admin_users, :username, :string, :null => false, :default => ""
  end

  def self.down
    remove_column :admin_users, :username
  end
end
