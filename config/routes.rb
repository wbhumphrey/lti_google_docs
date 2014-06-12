LtiGoogleDocs::Engine.routes.draw do
  root to: 'launch#index'
  namespace :launch do
    get '', to: :index
    post '', to: :index
    get 'auth', to: :auth
    get 'hello', to: :hello
    get 'factory', to: :factory
    get 'files', to: :files
  end

  namespace :register do
    get '', to: :index
    post '', to: :index
    get 'google', to: :google
    post 'google', to: :google
    get 'confirmed', to: :confirmed
    get 'canvas', to: :canvas
    get 'confirmed2', to: :confirmed2
  end

  namespace :labs do
    get '', to: :index
    post '', to: :start
    post 'new', to: :create
    get 'all', to: :all
    delete ':id', to: :remove
  end
#  resources :labs
#  post 'labs', to: 'labs#crazy'
end
