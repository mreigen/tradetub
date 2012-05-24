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
        end
        @user.update_attributes(params[:user])
        @user.update_with_password(params[:user])
      end

    end

  end
end
