class CreateShareRequests < ActiveRecord::Migration
  def change
    create_table :share_requests do |t|
      t.string :creator
      t.string :for
      t.string :file_id

      t.timestamps
    end
  end
end
