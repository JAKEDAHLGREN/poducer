class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :set_current_request_details
  before_action :authenticate

  # Check if user is logged in and has a role
  helper_method :current_user_role

  def current_user_role
    Current.user&.role
  end

  # Restrict access to Producer-only actions
  def ensure_producer
    redirect_to root_path, alert: "Access denied. Producers only." unless Current.user&.producer?
  end

  # Restrict access to Admin-only actions
  def ensure_admin
    redirect_to root_path, alert: "Access denied. Admins only." unless Current.user&.admin?
  end

  # Restricts access to Admins and Producer
  def ensure_admin_or_producer
    redirect_to root_path, alert: "Access denied. Admins and Producers only." unless Current.user&.admin? || Current.user&.producer?
  end

  private

  def authenticate
    if session_record = Session.find_by_id(cookies.signed[:session_token])
      Current.session = session_record
    else
      redirect_to sign_in_path
    end
  end

  def set_current_request_details
    Current.user_agent = request.user_agent
    Current.ip_address = request.ip
  end
end
