class AddCanvasModuleIdToCourses < ActiveRecord::Migration
  def change
    add_column :courses, :canvas_module_id, :string
  end
end
