module Authorizable
  extend ActiveSupport::Concern

  private

  # Generic method to authorize access to any resource
  def authorize_resource_access(resource, redirect_path = nil)
    redirect_path ||= determine_redirect_path(resource)
    redirect_to redirect_path, alert: "Access denied." unless can_access_resource?(resource)
  end

  # Check if current user can access a specific resource
  def can_access_resource?(resource)
    return true if Current.user&.admin?

    case resource
    when Podcast
      resource.user == Current.user
    when Episode
      resource.podcast.user == Current.user
    else
      false
    end
  end

  # Generic role-based authorization
  def ensure_role(required_role, redirect_path: root_path, message: "Access denied.")
    unless Current.user&.public_send("#{required_role}?")
      redirect_to redirect_path, alert: "#{message} #{required_role.capitalize}s only."
    end
  end

  # Determine appropriate redirect path based on resource type
  def determine_redirect_path(resource)
    case resource
    when Podcast
      podcasts_path
    when Episode
      if defined?(@podcast)
        podcast_episodes_path(@podcast)
      else
        podcasts_path
      end
    else
      root_path
    end
  end
end
