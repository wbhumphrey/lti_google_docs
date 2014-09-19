class CreateCanvasTools < ActiveRecord::Migration
  def change
    create_table :canvas_tools do |t|
      t.text :labid
      t.text :canvas_tool_id

      t.timestamps
    end
  end
end
