class CreateWantedServicesTable < ActiveRecord::Migration
  def self.up
    create_table :wanted_services do |t|
      t.integer :service_id
      t.integer :offer_id
    end
  end

  def self.down
    drop_table :wanted_services
  end
end
