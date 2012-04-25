class WantedSerive < ActiveRecord::Base
  belongs_to :offer
  
  def service
    Service.find(self.service_id)
  end
end