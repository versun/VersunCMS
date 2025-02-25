class NewslettersController < ApplicationController
  before_action :set_listmonk, only: [ :edit, :update]

  def edit
    @lists = @listmonk.fetch_lists if @listmonk.persisted? && @listmonk.api_key.present? && @listmonk.url.present?
  end

  def update
    if @listmonk.update(listmonk_params)
      redirect_to edit_newsletter, notice: 'Listmonk配置已更新'
    else
      @lists = @listmonk.fetch_lists if @listmonk.api_key.present? && @listmonk.url.present?
      render :edit
    end
  end

  private

  def set_listmonk
    @listmonk = Listmonk.first_or_initialize
  end

  def listmonk_params
    params.expect( listmonk: [ :api_key, :url, :selected_list_id ])
    # params.require(:listmonk).permit(:api_key, :url, :selected_list_id)
  end
end
