# encoding: utf-8

class AddPics < ActiveRecord::Migration[4.2]
  def self.up
    create_table :pics do |t|
      t.references :tutor
      t.string :basename
      t.boolean :has_lower

      t.timestamps
    end
  end

  def self.down
  end
end
