Rails.application.routes.draw do

  mount LtiGoogleDocs::Engine => "/lti_google_docs"
end
