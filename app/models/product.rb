class Product < ActiveRecord::Base
  
  belongs_to :user
  has_many :categories
  has_many :image_uploads
  
  # Named Scopes
  scope :available, lambda{ where("available_on < ?", Date.today) }
  scope :drafts, lambda{ where("available_on > ?", Date.today) }

  # Validations
  validates_presence_of :title
  validates_presence_of :price
  #validates_presence_of :image_file_name
  
  has_attached_file :image, 
                    :styles => { :original=> "", :medium => "238x238#", :thumb => "100x100#" },
                    :processors => [:auto_orient, :thumbnail]
                    
  # return trade type in string
  def get_trade_type
    case trade_type
      when 0
        "accept trade and cash"
      when 1
        "cash only"
      when 2
        "trade only"
    end
  end
end
