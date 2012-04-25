class RenameTypeColumnServicesTable < ActiveRecord::Migration
  def self.up
    rename_column :services, :type, :service_type
  end

  def self.down
    rename_column :services, :service_type, :type
  end
end
