class Api::V1::UsersController < ApplicationController
  def show
    @user = User.find params[:id]
    render :status => 200, :json => @user.to_json
  end
end