class UsersController < ApplicationController
  before_filter :authenticate_user!, :except => [:show]
  
  def index
    @users = User.all
  end
  
  def edit
    @user = User.find(params[:id])
  end
  
  def update
    user_info = params[:user] unless params[:user].blank?
    if !user_info.blank? && user_info[:password].empty?
     user_info.delete(:password) 
    end
    @user = User.find(params[:id])
    @user.update_attributes!(user_info)
    respond_with @user
  end

  def register_edit_info
    @user = User.find(params[:id])
    # save the info stuff
    if !params[:save].blank?
      pw = params[:user][:password]
      pwcf = params[:user][:password_confirmation]
      if !pw.blank? && !pwcf.blank? && (pw != pwcf)
        flash[:error] = "passwords don't match"
        redirect_to :back
      else
        @user.update_attributes(params[:user])
        @user.update_with_password(params[:user])
        @user.just_created = false
        respond_to do |format|
          if @user.save
            # have to signin again here because Devise will automatically sign you out 
            # after you changed the password. Note: bypass => true
            sign_in @user, :bypass => true
            format.html { redirect_to(items_path, :notice => 'Your personal info has been successfully updated.') }
            format.xml  { render :xml => @user, :status => :created, :location => @user }
          end
        end
      end
    end
  end

  def show
    @user = User.find(params[:id])
    @user_items = User.find(@user).items
  end
end