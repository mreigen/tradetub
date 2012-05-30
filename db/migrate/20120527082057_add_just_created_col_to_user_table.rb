class AddJustCreatedColToUserTable < ActiveRecord::Migration
  def self.up
    add_column :users, :just_created, :boolean, :default => :true
  end

  def self.down
    remove_column :users, :just_created
  end
end
