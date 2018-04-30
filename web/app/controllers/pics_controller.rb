# encoding: utf-8

class PicsController < ApplicationController
  def download
    @pic = Pic.find(params[:id])
    msg = "Original sheet not found. Try `locate #{File.basename @pic.source}` (stored path:  #{@pic.source})"
    raise ActionController::RoutingError.new(msg) unless @pic && @pic.sheet
    send_data(@pic.sheet.data,filename:File.basename(@pic.source))
  end
  def picture
    @pic = Pic.find(params[:id])
    send_data(@cpic.data,filename:@pic.basename)
  end
end
