class UsersController < ApplicationController
  def show
    @auser = User.find(params[:id])
    @products = Product.find_all_by_author(params[:id])
  end
end