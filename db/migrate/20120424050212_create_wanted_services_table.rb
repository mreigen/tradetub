class CreateWantedServicesTable < ActiveRecord::Migration
  def self.up
    create_table :wanted_services do |t|
      t.string :service_id
      t.string :offer_id
    end
  end

  def self.down
    drop_table :wanted_services
  end
end
