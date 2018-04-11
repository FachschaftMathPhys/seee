class Api::PicResource < JSONAPI::Resource
  attributes :basename, :source, :text, :step, :for
  has_one :tutor
  has_one :course
  has_one :term
end
