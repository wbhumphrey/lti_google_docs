class CreateClients < ActiveRecord::Migration
  def change
    create_table :clients do |t|
      t.string :client_name
      t.string :canvas_url
      t.string :canvas_clientid
      t.string :canvas_client_secret
      t.string :contact_email
      t.string :client_id
      t.string :client_secret

      t.timestamps
    end
  end
end
