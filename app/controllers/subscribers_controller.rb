class SubscribersController < ApplicationController

  before_action :check_logged_in_user
  before_action :check_manager_or_admin

  def index
    @subscribers = Subscriber.paginate(page: params[:page], per_page: 10)
  end

  def new
    @subscriber = Subscriber.new
  end


  ## Making this work for now! May not have edit method later!
  def edit

  end

  def destroy
    Subscriber.find(params[:id]).destroy
    flash[:success] = "Suscriber deleted!"
    redirect_to subscribers_path
  end

  def create
    # if Subscriber.where(:sub_params => current_user.id).blank?
         # no user record for this id
      @subscriber = Subscriber.new(sub_params)
      @subscriber.user_id = current_user.id
    # else
         # at least 1 record for this user
    # end
    if @subscriber.save
      flash[:success] = "Subscriber saved"
      redirect_to subscribers_path
    else
      @subscribers = Subscriber.paginate(page: params[:page], per_page: 10)
      flash[:danger] = "Subscriber not saved"
      render :index
    end
  end


  private

  # Never trust parameters from the scary internet, only allow the white list through.
  def sub_params
    # Rails 4+ requires you to whitelist attributes in the controller.
    params.fetch(:subscriber, {}).permit(:user_id)
  end

end
