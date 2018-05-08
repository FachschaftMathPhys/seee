# encoding: utf-8

class AddCriticalBoolToSemester < ActiveRecord::Migration[4.2]
  def self.up
    add_column :semesters, :critical, :boolean
  end

  def self.down
    remove_column :semesters, :critical
  end
end
