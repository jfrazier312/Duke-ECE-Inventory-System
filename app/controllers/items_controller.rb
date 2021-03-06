class ItemsController < ApplicationController
  before_action :check_logged_in_user
  before_action :check_manager_or_admin, only: [:create, :new, :edit, :update, :set_all_minimum_stock]
  before_action :check_admin_user, only: [:destroy]
  before_action :set_item,  only: [:edit, :edit_quantity, :update, :create_stocks, :convert_to_global, :convert_to_stocks, :delete_multiple_stocks]

  # GET /items
  # GET /items.json
  def index
    @tags = Tag.all

    items_excluded = Item.all
    items_required = Item.all
    items_stocked = Item.all

    if params[:excluded_tag_names]
      @excluded_tag_filters = params[:excluded_tag_names]
      items_excluded = Item.tagged_with_none(@excluded_tag_filters).select(:id)
    end
    if params[:required_tag_names]
      @required_tag_filters = params[:required_tag_names]
      items_required = Item.tagged_with_all(@required_tag_filters).select(:id)
    end
    if params[:stocked]
      @stocked = params[:stocked]
      items_stocked = Item.minimum_stock
    else
    end

    items_active = Item.where(id: items_excluded & items_required & items_stocked).filter_active

    @items = items_active.
        filter_by_search(params[:search]).
        filter_by_model_search(params[:model_search]).
        order('unique_name ASC').paginate(page: params[:page], per_page: 10)

  end

  # GET /items/1
  # GET /items/1.json
  def show
    if is_manager_or_admin?
      @item = Item.find(params[:id])
    else
      @item = Item.filter_active.find(params[:id])
    end

    outstanding_filter_params = {
        :status => "outstanding"
    }

    if !is_manager_or_admin?
      outstanding_filter_params[:user_id] = current_user.id
    end

    @requests = @item.requests.filter(outstanding_filter_params).paginate(page: params[:page], per_page: 10)
    @item_custom_fields = (@item.has_stocks) ?
        ItemCustomField.filter({ item_id: @item.id, is_global: true }) :
        ItemCustomField.filter({item_id: @item.id})
  end

  # GET /items/new
  def new
    @item = Item.new
  end

  # GET /items/1/edit
  def edit
    @item_custom_fields = ItemCustomField.where(item_id: @item.id)
  end

  def edit_quantity

  end

  # DELETE /items/1
  def destroy

    # Delete stocks with destroy_stocks_by_serial_tags! - surround with try catch
    item = Item.find(params[:id]).status = 'deactive'
    item.save!
    flash[:success] = "Item deleted!"
    redirect_to items_url
  end


  # POST /items
  # POST /items.json
  def create
    begin
      ActiveRecord::Base.transaction do
        @item = Item.new(item_params)
        @item.last_action = "created"
        @item.curr_user = current_user

        add_tags_to_item(@item, item_params)
        @item.save!

        CustomField.all.each do |cf|
          cf_name = cf.field_name
          icf = ItemCustomField.find_by(:item_id => @item.id, :custom_field_id => cf.id)
          icf.update_attributes!(CustomField.find_icf_field_column(cf.id) => params[cf_name])
        end
      end

      redirect_to item_url(@item.id)

    rescue Exception => e
      flash.now[:danger] = e.message
      render 'new'
    end

  end


  def import_upload

  end

  def bulk_import
    begin
      Item.bulk_import(params[:items_as_json].read)
      flash[:success] = "Bulk Import Successful"
      redirect_to items_path
    rescue NoMethodError => nme
      @imported_error_msg = "Must input a file"
      render 'import_upload'
    rescue Exception => e
      @imported_error_msg = e.message
      render 'import_upload'
    end
  end

  def update
    @item.curr_user = current_user

    @item.tags.delete_all
    add_tags_to_item(@item, item_params)

    min_stock_before = @item.minimum_stock

    if @item.update_attributes(item_params)
      if !params[:quantity_change].nil?
        update_quantity
      end

      if params[:minimum_stock]!=min_stock_before
        minimum_stock_email_changed_min_stock(min_stock_before,@item.minimum_stock,@item)
      end

      flash[:success] = "Item updated successfully"
      puts(@item.last_action)
      redirect_to @item
    else
      flash.now[:danger] = "Unable to edit!"
      render 'edit'
    end
  end
  #probably needs to go in the model but testing here
  def set_all_minimum_stock

    # This code below is repeated but it is just used to search for stuff.
    #TODO: Refactor later
    @tags = Tag.all

    items_excluded = Item.all
    items_required = Item.all
    items_stocked = Item.all
    if params[:excluded_tag_names]
      @excluded_tag_filters = params[:excluded_tag_names]
      items_excluded = Item.tagged_with_none(@excluded_tag_filters).select(:id)
    end
    if params[:required_tag_names]
      @required_tag_filters = params[:required_tag_names]
      items_required = Item.tagged_with_all(@required_tag_filters).select(:id)
    end
    if params[:stocked]
      @stocked = params[:stocked]
      items_stocked = Item.minimum_stock
    else
    end
    items_active = Item.where(id: items_excluded & items_required & items_stocked).filter_active

    @items = items_active.
        filter_by_search(params[:search]).
        filter_by_model_search(params[:model_search]).
        order('unique_name ASC').paginate(page: params[:page], per_page: 10)
  end


  def update_quantity

    if @item.has_stocks
      flash.now[:danger] = "Cannot directly change quantity of per asset Item"
      render :edit and return
    else
      temp_quantity = @item.quantity
      @item.quantity = @item.quantity + params[:quantity_change].to_f
      if !@item.save
        flash.now[:danger] = "Quantity unable to be changed"
        render 'edit'
      end
      minimum_stock_email(temp_quantity,@item.quantity, @item)
    end
  end

  def convert_to_stocks
		@item.curr_user = current_user
    if @item.convert_to_stocks
      flash[:success] = "Item successfully converted to Assets!"
      redirect_to item_stocks_path(@item)
    else
      flash[:danger] = "Item already converted to Assets"
      redirect_to items_path
    end
  end

  def convert_to_global
		@item.curr_user = current_user
    if @item.convert_to_global
      flash[:success] = "Item successfully converted to global"
      redirect_to item_path(@item)
    else
      flash.now[:danger] = "Item already global"
      render :show
    end
  end

  def create_stocks
		@item.curr_user = current_user
    if Item.is_valid_integer(params[:num_stocks])
      begin
        max = 10000
        if params[:num_stocks].to_i < max
          Stock.create_stocks!(params[:num_stocks].to_i, params[:id])
        elsif params[:num_stocks].size == 8
          Stock.create_stock!(params[:num_stocks], params[:id])
        else
          raise Exception.new("Cannot create more than #{max} assets at a time")
        end
        flash[:success] = "(#{params[:num_stocks]}) Assets successfully created!"
        redirect_to item_stocks_path @item and return
      rescue Exception => e
        flash[:danger] = e.message
        redirect_to item_stocks_path @item and return
      end
    else
      begin
        Stock.create_stock!(params[:num_stocks], params[:id])
        flash[:success] = "(#{params[:num_stocks]}) Asset successfully created!"
        redirect_to item_stocks_path @item and return
      rescue Exception => e
        flash[:danger] = e.message
        redirect_to item_stocks_path @item and return
      end
    end
  end

  def update_all_minimum_stock
    #Putting this line below just to test! Need to verify that it works.
    # binding.pry

    if !params[:item_ids].nil? && !params[:min_quantity].empty?
      update_min_stock_of_certain_items(params[:item_ids], params[:min_quantity])
      flash[:success] = "Minimum stock updated successfully"
    elsif  params[:item_ids].nil?
      flash[:warning] = "You must select at least one item"
    elsif  params[:min_quantity].empty?
      flash[:warning] = "You must specify the quantity"
    end
    redirect_to minimum_stock_path
  end

  ## helper method that will be used to update stocks and shit.
  def update_min_stock_of_certain_items(items, stock_quantity)
    # binding.pry
    items.each do |i|
      item_temp = Item.find(i)
      original_min_stock = item_temp.minimum_stock
      item_temp.update!(:minimum_stock => stock_quantity)
      puts "i is"
      puts i
      puts item_temp
      minimum_stock_email_changed_min_stock(original_min_stock, item_temp.minimum_stock,item_temp)
    end
  end

  def delete_multiple_stocks
    begin
      tags = Stock.get_tags_from_ids(params[:stock_ids])
			@item.curr_user = current_user 
			heyd = @item.create_log("acquired_or_destroyed_quantity", params[:stock_ids].size)
			@item.create_destruction_stock_logs(heyd, params[:stock_ids])
  
	     params[:stock_ids].each do |id|
        stock = Stock.find(id)
        if stock.available
          @item.delete_stock(stock)
        else
          req_item_stock = RequestItemStock.filter({status: 'loan', stock_id: id}).first
          tag_list = []
          tag_list << stock.serial_tag
          req_item_stock.request_item.disburse_loaned_subrequest!(tag_list)
        end
      end

	    flash[:success] = "Deleted #{tags} assets"
      redirect_to item_stocks_path @item
    rescue Exception => e
      flash[:danger] = "Could not delete all stocks. #{e.message}"
      redirect_to item_stocks_path @item
    end
  end

  private

  def set_item
    @item = Item.find(params[:id])
  end



  #THIS CODE IS DUPLICATED!! I WILL FIND A WAY TO REFACTOR LATER
  def minimum_stock_email_changed_min_stock(min_before, min_after, item)

    if min_before >= item.quantity && min_after < item.quantity
      if item.stock_threshold_tracked
        UserMailer.minimum_stock_min_stock_change(min_before, min_after, item).deliver_now
      end
    end
  end


  #THIS CODE IS DUPLICATED!! I WILL FIND A WAY TO REFACTOR LATER. LOL NOT

  def minimum_stock_email(q_before, q_after, item)
    if q_before >= item.minimum_stock && q_after < item.minimum_stock
      if item.stock_threshold_tracked
        puts "THE EMAIL WILL DELIVER NOW"
        UserMailer.minimum_stock_quantity_change(q_before, q_after, item).deliver_now
      end
    end
  end


  # Never trust parameters from the scary internet, only allow the white list through.
  def item_params
    # Rails 4+ requires you to whitelist attributes in the controller.
    params.fetch(:item, {}).permit(	:unique_name,
                                     :quantity,
                                     :model_number,
                                     :description,
                                     :minimum_stock,
                                     :stock_threshold_tracked,
                                     :search,
                                     :model_search,
                                     :status,
                                     :last_action,
                                     :has_stocks,
                                     :num_stocks,
                                     :tag_list=>[],
                                     item_custom_fields_attributes: [:short_text_content,
                                                                     :long_text_content,
                                                                     :integer_content,
                                                                     :float_content,
                                                                     :item_id, :custom_field_id, :id])
  end

end



