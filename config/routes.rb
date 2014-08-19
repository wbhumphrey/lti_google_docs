LtiGoogleDocs::Engine.routes.draw do
  namespace :lti_google_docs do
  namespace :labs do
    get 'instances/index'
    end
  end

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
    get ':id', to: :show
    post ':id', to: :show
    post ':id/view', to: :view
      
    get ':id/instances', to: 'instances#show'
    get 'instances/all', to: 'instances#all'
    delete 'instances/:id', to: 'instances#remove'
    resources :instances 
  end
#  resources :labs
#  post 'labs', to: 'labs#crazy'

#prototype for v2
  namespace :api do
      namespace :v2 do
        resources :clients do
            resources :courses do
                resources :labs do
                    resources :instances do
                    end
                end
            end
        end
    end
  end

# the above should produce paths such as: /api/v2/clients/0/courses/0/labs/0/instances/0
# the above 

end
