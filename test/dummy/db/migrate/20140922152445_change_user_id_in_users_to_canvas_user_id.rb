class ChangeUserIdInUsersToCanvasUserId < ActiveRecord::Migration
  def change
    rename_column :users, :userid, :canvas_user_id
  end
end
