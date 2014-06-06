LtiGoogleDocs::Engine.routes.draw do
  root to: 'launch#index'
  namespace :launch do
    get '', to: :index
    post '', to: :index
    get 'auth', to: :auth
    get 'hello', to: :hello
  end

  namespace :register do
    get '', to: :index
    post '', to: :index
    get 'google', to: :google
    post 'google', to: :google
    get 'confirmed', to: :confirmed
  end
end
