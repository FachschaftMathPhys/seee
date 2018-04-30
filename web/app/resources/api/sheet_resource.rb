class Api::SheetResource < JSONAPI::Resource
  attributes :data, :uid
  has_many :c_pics
  has_many :pics
  def data
    Base64.encode64(@model.data)
  end
  def data=(value)
    @model.data=Base64.decode64(value)
  end
  filter :uid
end
