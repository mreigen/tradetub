ActiveadminDepot::Application.routes.draw do

  ActiveAdmin.routes(self)

  get "cart" => "cart#show"
  get "cart/add/:id" => "cart#add", :as => :add_to_cart
  post "cart/remove/:id" => "cart#remove", :as => :remove_from_cart
  post "cart/checkout" => "cart#checkout", :as => :checkout
  
  match 'signup' => 'users#new', :as => :signup
  match 'user/:id/register_edit_info' => 'users#register_edit_info', :as => :register_edit_info
  
  devise_for :users, :controllers => { :omniauth_callbacks => "omniauth_callbacks" }
  
  devise_for :users, :controllers => {:sessions => 'devise/sessions'}, :skip => [:sessions] do 
      get 'login' => 'devise/sessions#new', :as => :new_user_session 
      post 'login' => 'devise/sessions#create', :as => :user_session 
      get 'logout' => 'devise/sessions#destroy', :as => :destroy_user_session 
  end
  #match 'admin/logout' => 'sessions#destroy', :as => :logout
  #match '/login' => 'sessions#new', :as => :login
  #put '/offers/:id/respond/:respond' => 'offers#respond'
  get '/user/:user_id/items' => 'items#index'

  match 'offer/:id/counter_offer', :to => 'offers#counter_offer', :as => :counter_offer
  match 'offer/:id/send_counter_offer' => 'offers#send_counter_offer', :as => :send_counter_offer

  resources :sessions
  resources :products
  resources :image_uploads
  resources :categories
  
  resources :offers
  resources :items
  resources :users
  resources :comments
  resources :transactions
  
  root :to => "products#index"
end
