class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :ensure_authenticated_user, only: %i[ edit update ]

  def new
  end

  def create
    if user = User.find_by(user_name: params[:user_name])
      PasswordResetJob.perform_later(user.id)
    end

    redirect_to new_session_path, notice: "Password reset instructions sent (if user with that username exists)."
  end

  def edit
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      terminate_session
      redirect_to new_session_path, notice: "Password has been reset."
    else
      redirect_to edit_password_path, alert: "Passwords did not match."
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: "Password reset link is invalid or has expired."
    end

    def ensure_authenticated_user
      unless authenticated? && (@user = Current.session&.user)
        redirect_to new_session_path, alert: "Please login first."
      end
    end
end
