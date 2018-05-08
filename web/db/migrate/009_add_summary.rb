# encoding: utf-8

class AddSummary < ActiveRecord::Migration[4.2]
  def self.up
    add_column :courses, :summary, :text
  end

  def self.down
    remove_column :courses, :summary
  end
end
