# encoding: utf-8

class Courseprofpics < ActiveRecord::Migration[4.2]
  def self.up
     rename_column :c_pics, :course_id, :course_prof_id
  end

  def self.down
     rename_column :c_pics, :course_prof_id, :course_id
  end
end
