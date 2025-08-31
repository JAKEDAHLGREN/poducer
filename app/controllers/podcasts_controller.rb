class PodcastsController < ApplicationController
  before_action :set_podcast, only: [ :show, :edit, :update, :destroy ]

  def index
    @podcasts = Podcast.all
  end

  def show
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
  end

  def update
    if @podcast.update(podcast_params)
      redirect_to @podcast, notice: "Podcast updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @podcast.destroy
      redirect_to podcasts_path, notice: "Podcast deleted successfully"
    else
      redirect_to @podcast, alert: "Failed to delete podcast"
    end
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:id])
  end

  def podcast_params
    params.require(:podcast).permit(:name, :description, :website_url, :primary_category, :secondary_category, :tertiary_category, :cover_art)
  end
end
