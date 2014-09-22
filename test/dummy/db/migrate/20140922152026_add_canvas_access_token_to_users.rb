class AddCanvasAccessTokenToUsers < ActiveRecord::Migration
  def change
    add_column :users, :canvas_access_token, :string
  end
end
