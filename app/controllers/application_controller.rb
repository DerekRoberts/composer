class ApplicationController < ActionController::Base
  protect_from_forgery
  layout :layout_by_resource

  def layout_by_resource
    if devise_controller?
      "users"
    else
      "application"
    end
  end
  
  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_url, :alert => exception.message
  end
  
end
