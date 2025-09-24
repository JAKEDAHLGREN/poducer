class PodcastStepsController < ApplicationController
  include Wicked::Wizard
  steps :overview, :cover, :media, :website, :categories, :summary

  before_action :set_podcast
  before_action :set_steps

  def show
    # Clear any stored errors when showing a fresh form
    session.delete(:validation_errors)
    render_wizard
  end

  def update
    # Clear any previous errors
    session.delete(:validation_errors)

    # Only assign attributes if there are podcast params (not on summary step)
    if params[:podcast].present?
      @podcast.assign_attributes(podcast_params)
      # Manually normalize the website URL before validation
      normalize_website_url
    end

    # Add debugging
    Rails.logger.debug "Current step: #{step}"
    Rails.logger.debug "Podcast name: '#{@podcast.name}'"
    Rails.logger.debug "Podcast description: '#{@podcast.description}'"

    # For summary step, we don't need to validate - just publish
    if step == steps.last
      @podcast.update(status: :published)
      redirect_to podcasts_path, notice: "Podcast created successfully"
    else
      # Validate based on current step using a custom context
      valid = case step
      when :overview
        @podcast.valid?(:overview_step)
      when :categories
        @podcast.valid?(:categories_step)
      else
        true # No validation for other steps
      end

      Rails.logger.debug "Is valid for #{step}?: #{valid}"
      Rails.logger.debug "Errors: #{@podcast.errors.full_messages}"

      if valid
        # Save the podcast at each step to preserve data (including files)
        if @podcast.save(validate: false) # Save without validation since we already validated
          redirect_to next_wizard_path
        else
          render step
        end
      else
        # Store errors in session to survive the render
        session[:validation_errors] = @podcast.errors.full_messages
        Rails.logger.debug "Storing errors in session: #{session[:validation_errors].inspect}"
        render step
      end
    end
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
  end

  def set_steps
    @steps = steps
  end

  def podcast_params
    params.require(:podcast).permit(:name, :description, :website_url, :primary_category, :secondary_category, :tertiary_category, :cover_art, media: [])
  end

  def normalize_website_url
    if @podcast.website_url.present?
      url = @podcast.website_url.strip
      unless url.match?(%r{^https?://})
        url = "https://#{url}"
      end
      @podcast.website_url = url
    end
  end

  def redirect_to_finish_wizard
    redirect_to @podcast, notice: "Thank you for creating your podcast."
  end

  def finish_wizard_path
    @podcast
  end
end
