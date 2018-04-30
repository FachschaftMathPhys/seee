# encoding: utf-8

class CpicsController < ApplicationController
  def download
    @cpic = CPic.find(cpics_params[:id])
    msg = "Original sheet not found. Try `locate #{File.basename @cpic.source}` (stored path:  #{@cpic.source})"
    p msg
    raise ActionController::RoutingError.new(msg) unless @cpic && @cpic.sheet
    send_data(@cpic.sheet.data,filename:File.basename(@cpic.source))
  end
  def picture
    @cpic = CPic.find(params[:id])
    send_data(@cpic.data,filename:@cpic.basename)
  end
  private
  def cpics_params
    params.permit(:id)
  end
end
