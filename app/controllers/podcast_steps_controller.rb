class PodcastStepsController < ApplicationController
  include Wicked::Wizard
  steps :overview, :media, :categories, :summary

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
      # Handle cover removal flag before attribute assignment
      if params[:podcast][:remove_cover_art] == "1" && @podcast.cover_art.attached?
        @podcast.cover_art.purge
      end
      @podcast.assign_attributes(podcast_params) if podcast_params.present?
      # Manually normalize the website URL before validation
      normalize_website_url
    end

    # For summary step, we don't need to validate - just publish
    if step == steps.last
      process_cover_art_label if params[:podcast].present?
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

      if valid
        # Save the podcast at each step to preserve data (including files)
        if @podcast.save(validate: false) # Save without validation since we already validated
          process_cover_art_label
          redirect_to next_wizard_path
        else
          render step
        end
      else
        # Store errors in session to survive the render
        session[:validation_errors] = @podcast.errors.full_messages
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
    params.require(:podcast).permit(:name, :description, :website_url, :primary_category, :secondary_category, :tertiary_category, :cover_art, :explicit, :episode_type)
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

  def process_cover_art_label
    return unless @podcast.cover_art.attached?

    labels = (params[:cover_art_labels].to_unsafe_h if params[:cover_art_labels].present?) || {}
    blob = @podcast.cover_art.blob
    attachment = @podcast.cover_art.attachment

    # Support filename-based labels from Stimulus (cover_art_labels_json)
    if params[:cover_art_labels_json].present?
      begin
        filename_labels = JSON.parse(params[:cover_art_labels_json])
        label_from_json = filename_labels[blob.filename.to_s]
        labels[blob.id.to_s] = label_from_json if label_from_json.present?
      rescue JSON::ParserError
        # Ignore JSON parse errors
      end
    end

    label_value = labels[attachment.id.to_s].presence ||
                  labels[blob.id.to_s].presence
    return if label_value.blank?

    new_metadata = blob.metadata.merge("label" => label_value.to_s.strip)
    blob.update!(metadata: new_metadata)
  rescue StandardError
    # Silently ignore metadata update errors
  end
end
