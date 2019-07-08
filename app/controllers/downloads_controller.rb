class DownloadsController < ApplicationController
  before_action :set_asset, :check_auth
  before_action :set_derivative, only: :derivative


  #GET /downloads/:asset_id
  def original

  end

  #GET /downloads/:asset_id/:derivative_key
  def derivative

  end

  private

  def set_asset
    @asset = Asset.find_by_friendlier_id!(params[:asset_id])
  end

  def check_auth
    authorize! :read, @asset
  end

  def set_derivative
    @derivative = @asset.derivative_for(params[:derivative_key])
    unless @derivative
      # We could use custom subclass of RecordNotFound with machine-readable details
      raise ActiveRecord::RecordNotFound.new("Couldn't find Kithe::Derivative for '#{@asset.id}' with key '#{params[:derivative_key]}'",
                                              "Kithe::Derivative")
    end
  end
end
