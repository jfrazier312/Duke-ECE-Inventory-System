class Stock < ApplicationRecord
  include Filterable


  SERIAL_TAG_LENGTH = 8

  # Relation with RequestItem
  has_many :request_items, -> { distinct }, :through => :request_item_stocks
  has_many :request_item_stocks, dependent: :destroy

  # Relation with Tags
  has_many :tags, -> { distinct },  :through => :item_tags
  has_many :item_tags

  # Relationship with CustomField
  has_many :custom_fields, -> { distinct }, :through => :stock_custom_fields
  has_many :stock_custom_fields, dependent: :destroy
  accepts_nested_attributes_for :stock_custom_fields

  # Scope available for filterable
  scope :available, -> (available) { where available: available }
  scope :request_item_id, -> (request_item_id) { joins(:request_item_stock).where(request_item_stocks: { request_item_id: request_item_id }) }
  scope :serial_tag, -> (serial_tag) { where serial_tag: serial_tag }
  scope :item_id, -> (item_id) { where item_id: item_id }

  # Belongs to items
  belongs_to :item

  # Relation with Logs
  has_many :logs

  before_create {
    generate_serial_tag!
  }

  after_create {
    create_custom_fields_for_stocks(self.id)
  }

  ## Validations
  validates :serial_tag,
            length: { :minimum => SERIAL_TAG_LENGTH, :maximum => SERIAL_TAG_LENGTH },
            uniqueness: { case_sensitive: true }, :allow_nil => true



  def generate_serial_tag!
    if !self.class.exists?(serial_tag: serial_tag) && !self.serial_tag.nil?
      return
    end

    begin
      self.serial_tag = generate_code(SERIAL_TAG_LENGTH)
    end while self.class.exists?(serial_tag: serial_tag)
  end

  def self.create_stocks!(num, item_id)
    raise Exception.new('Inputted Item does not exist') unless Item.exists?(item_id)
    item = Item.find(item_id)
    raise Exception.new('Inputted Item is not per-asset!') unless item.has_stocks

    Stock.transaction do
  		iteid = item.create_log("acquired_or_destroyed_quantity", num)
	    for i in 1..num do
				stock = Stock.create!(item_id: item_id, available: true)
        item.update_item_quantity_on_stock_creation
				sil = StockItemLog.new(:item_log_id => iteid, :stock_id => stock.id, :curr_serial_tag => stock.serial_tag)
				sil.save!
      end

    end
  end

  def self.create_stock!(serial_tag, item_id)
    stock = Stock.create!(serial_tag: serial_tag, item_id: item_id)
    Item.find(item_id).update_item_quantity_on_stock_creation
 		iteid = Item.find(item_id).create_log("acquired_or_destroyed_quantity", 1)
		sil = StockItemLog.new(:item_log_id => iteid, :stock_id => stock.id, :curr_serial_tag => stock.serial_tag)
		sil.save! 
  end

  def self.filter_by_search(search_input)
    where("serial_tag ILIKE ?", "%#{search_input}%")
  end

  def self.get_tags_from_ids(ids)
    tags = []
    ids.each do |id|
      tags << Stock.find(id).serial_tag
    end
    tags
  end

  ## Private variables
  private
  def generate_code(number)
    charset = Array('A'..'Z') + Array('a'..'z') + Array('0'..'9')
    Array.new(number) { charset.sample }.join
  end

  private
  def create_custom_fields_for_stocks(stock_id)
    CustomField.filter({:is_stock => true}).each do |cf|
      StockCustomField.create!(stock_id: stock_id, custom_field_id: cf.id,
                               short_text_content: nil,
                               long_text_content: nil,
                               integer_content: nil,
                               float_content: nil)
    end
  end

end
