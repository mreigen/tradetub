class ApplicationController < ActionController::Base
  #protect_from_forgery
  
  def after_sign_in_path_for(resource)
    register_edit_info_path(resource)
  end
end
