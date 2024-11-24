class UsersController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  def new
    if User.exists?
      redirect_to root_path, notice: "Admin user already exists."
    else
      @user = User.new
    end
  end

  def edit
    @user = Current.user
  end

  def update
    @user = Current.user
    if @user.update(user_params)
      redirect_to admin_posts_path, alert: "Account was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to new_session_path, notice: "Admin user created successfully."
    else
    render :new
    end
  end

  private
  def user_params
    params.require(:user).permit(:user_name, :password, :password_confirmation)
  end
end
