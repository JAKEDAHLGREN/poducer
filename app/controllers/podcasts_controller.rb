class PodcastsController < ApplicationController
  def index
    @podcasts = Podcast.all
  end

  def show
    @podcast = Podcast.find(params[:id])
  end

  def new
    @podcast = Podcast.new
  end

  def create
    @podcast = Podcast.new(podcast_params)
    @podcast.user = Current.user

    if @podcast.save
      redirect_to @podcast, notice: "Podcast created successfully"
    else
      # Add this line to see validation errors in the logs
      Rails.logger.error "Podcast validation errors: #{@podcast.errors.full_messages}"
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @podcast = Podcast.find(params[:id])
  end

  def update
    @podcast = Podcast.find(params[:id])

    if @podcast.update(podcast_params)
      redirect_to @podcast, notice: "Podcast updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @podcast = Podcast.find(params[:id])

    if @podcast.destroy
      redirect_to podcasts_path, notice: "Podcast deleted successfully"
    else
      redirect_to @podcast, alert: "Failed to delete podcast"
    end
  end

  private

  def podcast_params
    params.require(:podcast).permit(:name, :description, :website_url, :primary_category, :secondary_category, :tertiary_category, :cover_art)
  end
end
