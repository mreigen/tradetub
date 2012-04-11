class Product < ActiveRecord::Base
  
  belongs_to :admin_user
  # Named Scopes
  scope :available, lambda{ where("available_on < ?", Date.today) }
  scope :drafts, lambda{ where("available_on > ?", Date.today) }

  # Validations
  validates_presence_of :title
  validates_presence_of :price
  validates_presence_of :image_file_name

  
  has_attached_file :image, :styles => { :medium => "238x238>", :thumb => "100x100>" }

end
