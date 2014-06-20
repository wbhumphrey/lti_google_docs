class CreateLabs < ActiveRecord::Migration
  def change
    create_table :labs do |t|
      t.string :title
      t.string :folderName
      t.string :folderId
      t.string :participation

      t.timestamps
    end
  end
end
