class OfferService < ActiveRecord::Base
  belongs_to :offer
  
  def service
    Service.find(self.service_id)
  end
end