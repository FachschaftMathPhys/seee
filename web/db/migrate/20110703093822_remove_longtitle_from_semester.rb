# encoding: utf-8

class RemoveLongtitleFromSemester < ActiveRecord::Migration[4.2]
  def self.up
    remove_column :semesters, :role
  end

  def self.down
    add_column :semesters, :role, :string
  end
end
