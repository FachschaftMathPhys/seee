class Api::FormResource < JSONAPI::Resource
  attributes :name, :critical, :content, :languages
  has_one :term
  def critical
    @model.critical?
  end
  def self.updatable_fields(context)
    super - [:critical]
  end
  def self.creatable_fields(context)
    super - [:critical]
  end
end
