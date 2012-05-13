class CreateOfferServicesTable < ActiveRecord::Migration
  def self.up
    create_table :offer_services do |t|
      t.string :service_id
      t.string :offer_id
    end
  end

  def self.down
    drop_table :offer_services
  end
end
