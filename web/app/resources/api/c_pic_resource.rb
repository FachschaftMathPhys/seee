class Api::CPicResource < JSONAPI::Resource
  attributes :step, :text, :source, :basename
  has_one :course_prof
  has_one :course
  has_one :term
end
