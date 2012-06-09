ActiveAdmin.register User do
  index do
    column :email
    column :current_sign_in_at
    column :last_sign_in_at
    column :sign_in_count
    default_actions
  end

  form do |f|
    f.inputs "Admin Details" do
      f.input :email
    end
    f.buttons
  end

  show do |u|
    render :partial => "show_user", :locals => { :user => u }
  end
  
  after_create { |admin| admin.send_reset_password_instructions }

  def password_required?
    new_record? ? false : super
  end

  # ===================================================================
  # controllers stuff
  # ===================================================================
  controller do
  
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

  end
end
