class CreateOfferServicesTable < ActiveRecord::Migration
  def self.up
    create_table :offer_services do |t|
      t.integer :service_id
      t.integer :offer_id
    end
  end

  def self.down
    drop_table :offer_services
  end
end
