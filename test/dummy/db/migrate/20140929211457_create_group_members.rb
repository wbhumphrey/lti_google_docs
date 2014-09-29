class CreateGroupMembers < ActiveRecord::Migration
  def change
    create_table :group_members do |t|
      t.string :lti_user_id
      t.string :lti_group_id
      t.string :canvas_user_id

      t.timestamps
    end
  end
end
