class Api::CPicResource < JSONAPI::Resource
  attributes :step, :text, :source, :basename, :dt
  has_one :course_prof
  has_one :course
  has_one :term
  has_one :sheet
  def dt
    Base64.encode64(@model.data)
  end
  def dt=(value)
    @model.data=Base64.decode64(value)
  end
end
