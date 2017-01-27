Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  get 'welcome/index'

  resources :users, except: :new
    get '/signup', to: 'users#new'
    post '/signup', to: 'users#create'

  resources :users do
    member do
      get :confirm_email
    end
  end

  resources :requests
  resources :items


  #Login and Sessions routes
  get   '/login',   to: 'sessions#new'      #Describes the login screen
  post  '/login',   to: 'sessions#create'   #Handles actually logging in
  delete '/logout', to: 'sessions#destroy'  #Handles logging out


  # User request page for admin
  resources :accountrequests
  get '/accountrequests', to: 'accountrequests#index'

  resources :accountrequests do
    member do
      get :approve_user
    end
  end

  root 'welcome#index'

end
