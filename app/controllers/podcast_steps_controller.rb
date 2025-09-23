class PodcastStepsController < ApplicationController
  include Wicked::Wizard
  steps :overview, :cover, :media, :website, :categories, :summary

  before_action :set_podcast
  before_action :set_steps

  def show
    render_wizard
  end

  def update
    # Only assign attributes if there are podcast params (not on summary step)
    if params[:podcast].present?
      @podcast.attributes = podcast_params
      # Manually normalize the website URL before validation
      normalize_website_url
    end

    if @podcast.valid? || step == steps.last
      if @podcast.save
        if step == steps.last
          @podcast.update(status: :published)
          redirect_to podcasts_path, notice: "Podcast created successfully"
        else
          redirect_to next_wizard_path
        end
      else
        render_wizard
      end
    else
      render_wizard
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
