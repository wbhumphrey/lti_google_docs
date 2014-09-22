class AddAccessTokenToClients < ActiveRecord::Migration
  def change
    add_column :clients, :lti_access_token, :string
  end
end
