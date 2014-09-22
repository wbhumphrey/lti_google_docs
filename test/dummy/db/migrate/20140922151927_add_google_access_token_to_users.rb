class AddGoogleAccessTokenToUsers < ActiveRecord::Migration
  def change
    add_column :users, :google_access_token, :string
  end
end
