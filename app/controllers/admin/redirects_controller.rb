class Admin::RedirectsController < Admin::BaseController
  before_action :set_redirect, only: [ :edit, :update, :destroy ]

  def index
    @redirects = Redirect.order(created_at: :desc)
  end

  def new
    @redirect = Redirect.new
  end

  def create
    @redirect = Redirect.new(redirect_params)

    if @redirect.save
      redirect_to admin_redirects_path, notice: "Redirect was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @redirect.update(redirect_params)
      redirect_to admin_redirects_path, notice: "Redirect was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @redirect.destroy!
    redirect_to admin_redirects_path, status: :see_other, notice: "Redirect was successfully deleted."
  end

  private

  def set_redirect
    @redirect = Redirect.find(params[:id])
  end

  def redirect_params
    params.require(:redirect).permit(:regex, :replacement, :permanent, :enabled)
  end
end
