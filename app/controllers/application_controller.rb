class ApplicationController < ActionController::Base
  include Authorizable

  allow_browser versions: :modern

  before_action :set_current_request_details
  before_action :authenticate

  helper_method :current_user_role

  def current_user_role
    Current.user&.role
  end

  # Convenience methods that use the concern
  def ensure_producer
    ensure_role(:producer)
  end

  def ensure_admin
    ensure_role(:admin)
  end

  def ensure_admin_or_producer
    unless Current.user&.admin? || Current.user&.producer?
      redirect_to root_path, alert: "Access denied. Admins and Producers only."
    end
  end

  def root
    if Current.user&.producer?
      redirect_to producer_episodes_path
    else
      redirect_to dashboards_path
    end
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
