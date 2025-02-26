class NewslettersController < ApplicationController
  before_action :set_listmonk, only: [ :edit, :update]

  def edit
    if @listmonk.persisted? && @listmonk.api_key.present? && @listmonk.url.present?
      @lists = @listmonk.fetch_lists
      @templates  = @listmonk.fetch_templates
    end

  end

  def update
    if @listmonk.update(listmonk_params)
      redirect_to edit_newsletter_path, notice: 'Listmonk updated.'
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
    params.expect( listmonk: [ :enabled, :username, :api_key, :url, :list_id, :template_id ])
  end
end
