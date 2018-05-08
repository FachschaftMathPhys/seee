# encoding: utf-8

class CreateForms < ActiveRecord::Migration[4.2]
  def self.up
    create_table :forms do |t|
      t.references :semester
      t.string :name
      t.text :content

      t.timestamps
    end
  end

  def self.down
    drop_table :forms
  end
end
