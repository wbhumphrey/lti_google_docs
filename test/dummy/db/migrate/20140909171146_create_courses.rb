class CreateCourses < ActiveRecord::Migration
  def change
    create_table :courses do |t|
      t.text :client_id
      t.text :canvas_course_id

      t.timestamps
    end
  end
end
