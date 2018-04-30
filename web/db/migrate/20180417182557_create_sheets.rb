class CreateSheets < ActiveRecord::Migration[5.1]
  def change
    create_table :sheets do |t|
      t.string :uid
      t.binary :data
      t.string :type

      t.timestamps
    end
  end
end
