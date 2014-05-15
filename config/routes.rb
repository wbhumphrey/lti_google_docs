LtiGoogleDocs::Engine.routes.draw do
  root to: 'launch#index'
  namespace :launch do
    get '', to: :index
    post '', to: :index
  end
end
