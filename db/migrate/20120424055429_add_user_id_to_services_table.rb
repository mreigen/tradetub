class AddUserIdToServicesTable < ActiveRecord::Migration
  def self.up
    add_column :services, :user_id, :integer
  end

  def self.down
    remove_column :services, :user_id
  end
end
