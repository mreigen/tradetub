class AdminUsersController < ApplicationController
  def show
    @auser = AdminUser.find(params[:id])
    @products = Product.find_all_by_author(params[:id])
  end
end