class AddCourseIdToLabs < ActiveRecord::Migration
  def change
    add_column :labs, :course_id, :integer
  end
end
