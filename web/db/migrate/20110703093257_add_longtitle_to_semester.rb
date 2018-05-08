# encoding: utf-8

class AddLongtitleToSemester < ActiveRecord::Migration[4.2]
  def self.up
    add_column :semesters, :role, :string
  end

  def self.down
    remove_column :semesters, :role
  end
end
