class User < ActiveRecord::Base

  has_many :orders, :dependent => :destroy
  has_many :products, :dependent => :destroy

  devise :database_authenticatable, 
         :recoverable, :rememberable, :trackable, :validatable, :authentication_keys => [:email]
  
end
