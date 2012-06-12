class Category < ActiveRecord::Base
	has_many :products
	
	scope :asc, order("categories.fullname ASC")
end
