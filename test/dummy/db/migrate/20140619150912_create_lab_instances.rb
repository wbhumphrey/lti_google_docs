class CreateLabInstances < ActiveRecord::Migration
  def change
    create_table :lab_instances do |t|
      t.string :labid
      t.string :studentid
      t.string :fileid

      t.timestamps
    end
  end
end
