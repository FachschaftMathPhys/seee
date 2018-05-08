# encoding: utf-8

class FormIToOldFormI < ActiveRecord::Migration[4.2]
  def self.up
    rename_column :courses, :form, :old_form_i
  end

  def self.down
    rename_column :courses, :old_form_i, :form
  end
end
