LtiGoogleDocs::Engine.routes.draw do
  root to: 'launch#index'
  namespace :launch do
    get '', to: :index
    post '', to: :index
    get 'register', to: 'register#index'
  end

  namespace :register do
    get '', to: :index
    post '', to: :index
  end
end
