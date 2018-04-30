class Api::PicResource < JSONAPI::Resource
  has_one :tutor
  attributes :basename, :source, :text, :step,:data
  has_one :course
  has_one :term
  has_one :sheet
  def data
    Base64.encode64(@model.data)
  end
  def data=(value)
    @model.data=Base64.decode64(value)
  end
  def self.creatable_fields(context)
    super
  end
  def self.updatable_fields(context)
    super
  end
end
