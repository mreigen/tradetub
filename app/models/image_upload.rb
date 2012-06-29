class ImageUpload < ActiveRecord::Base
  belongs_to :item
  attr_accessor :delete_image
  attr_accessible :image
  has_attached_file :image, :styles => { :large => "520x380>", :medium => "238x238#", :thumb => "100x100#" }
  
  before_validation { :image.clear if delete_image == '1'}
end
