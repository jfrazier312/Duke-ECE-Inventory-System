class Stock < ApplicationRecord

  SERIAL_TAG_LENGTH = 8

  validates :serial_tag, presence: true, uniqueness: { case_sensitive: true }

  # Relation with Tags
  has_many :tags, -> { distinct },  :through => :item_tags
  has_many :item_tags

  # Relationship with CustomField
  has_many :custom_fields, -> { distinct }, :through => :stock_custom_fields
  has_many :stock_custom_fields, dependent: :destroy
  accepts_nested_attributes_for :stock_custom_fields


  # Relation with Logs
  has_many :logs

  before_create {
    generate_serial_tag!
  }

  before_validation {
  }

  ## Validations
  validates :serial_tag, presence: true,
            length: { :minimum => SERIAL_TAG_LENGTH, :maximum => SERIAL_TAG_LENGTH },
            unique: true

  def generate_serial_tag!
    begin
      self.auth_token = generate_code(SERIAL_TAG_LENGTH)
    end while self.class.exists?(serial_tag: serial_tag)
  end

  ## Private variables
  private
  def generate_code(number)
    charset = Array('A'..'Z') + Array('a'..'z') + Array('0'..'9')
    Array.new(number) { charset.sample }.join
  end

end
