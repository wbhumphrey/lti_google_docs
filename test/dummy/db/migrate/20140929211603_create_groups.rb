class CreateGroups < ActiveRecord::Migration
  def change
    create_table :groups do |t|
      t.string :lti_course_id
      t.string :lti_lab_id
      t.string :name
      t.string :lti_lab_instance
      t.string :canvas_group_id

      t.timestamps
    end
  end
end
