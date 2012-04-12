ActiveadminDepot::Application.routes.draw do

  resources :image_uploads

  resources :categories

  ActiveAdmin.routes(self)

  get "cart" => "cart#show"
  get "cart/add/:id" => "cart#add", :as => :add_to_cart
  post "cart/remove/:id" => "cart#remove", :as => :remove_from_cart
  post "cart/checkout" => "cart#checkout", :as => :checkout

  match 'signup' => 'users#new', :as => :signup
  devise_for :users, :controllers => {:sessions => 'active_admin/devise/sessions'}, :skip => [:sessions] do 
      get 'login' => 'active_admin/devise/sessions#new', :as => :new_user_session 
      post 'login' => 'active_admin/devise/sessions#create', :as => :user_session 
      get 'logout' => 'active_admin/devise/sessions#destroy', :as => :destroy_user_session 
  end
  #match 'admin/logout' => 'sessions#destroy', :as => :logout
  match 'admin/login' => 'sessions#new', :as => :login
  resources :sessions
  resources :products

  root :to => "products#index"
end
