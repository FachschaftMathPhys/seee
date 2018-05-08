# encoding: utf-8

class CreateSemesters < ActiveRecord::Migration[4.2]
  def self.up
    create_table :semesters do |t|
      t.date :firstday
      t.date :lastday
      t.string :title

      t.timestamps
    end
  end

  def self.down
    drop_table :semesters
  end
end
