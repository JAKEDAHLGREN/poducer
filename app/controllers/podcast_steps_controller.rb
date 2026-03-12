class PodcastStepsController < ApplicationController
  include Wicked::Wizard
  include BlobLabelable
  steps :overview, :media, :categories, :summary

  before_action :set_podcast
  before_action -> { authorize_resource_access(@podcast) }
  before_action :set_steps

  def show
    render_wizard
  end

  def update
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

    # For summary step, validate required fields before publishing
    if step == steps.last
      overview_ok = @podcast.valid?(:overview_step)
      categories_ok = @podcast.valid?(:categories_step)
      if overview_ok && categories_ok
        process_single_blob_label(@podcast, :cover_art, label_key: :cover_art_labels)
        @podcast.update(status: :published)
        redirect_to podcasts_path, notice: "Podcast created successfully"
      else
        render :summary
      end
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
          process_single_blob_label(@podcast, :cover_art, label_key: :cover_art_labels)
          redirect_to next_wizard_path
        else
          render step
        end
      else
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

  def finish_wizard_path
    @podcast
  end
end
