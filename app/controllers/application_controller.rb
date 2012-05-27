class ApplicationController < ActionController::Base
  #protect_from_forgery
=begin  
  def after_sign_in_path_for(resource)
    user_registered = User.where(:email => )
    if @user.persisted? # user already registered, go to referrer
      root_path
    else
      register_edit_info_path(resource)
    end
  end
=end
end
