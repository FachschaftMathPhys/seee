# encoding: utf-8

class CreateCourseProfs < ActiveRecord::Migration[4.2]
  def self.up
    create_table :course_profs do |t|
      t.references :course
      t.references :prof
    end
  end

  def self.down
    drop_table :course_profs
  end
end
