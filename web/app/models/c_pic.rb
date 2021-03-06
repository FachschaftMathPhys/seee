# encoding: utf-8

class CPic < ApplicationRecord
  belongs_to :course_prof, :inverse_of => :c_pics
  belongs_to :sheet
  has_one :course, :through => :course_prof
  has_one :term, :through => :course_prof

  validates :step, :numericality => { :only_integer => true }

  def for
    "prof " + course_prof.prof.fullname
  end

  def step
    read_attribute(:step) || 0
  end
end
