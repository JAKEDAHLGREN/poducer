class PodcastsController < ApplicationController
  before_action :set_podcast, only: [ :show, :edit, :update, :destroy ]
  before_action -> { authorize_resource_access(@podcast) }, only: [ :show, :edit, :update, :destroy ]

  def index
    # Filter out empty draft podcasts - only show drafts that have at least a name
    base_podcasts = Current.user.admin? ? Podcast.all : Current.user.podcasts
    @podcasts = base_podcasts.where.not(status: :draft, name: [ nil, "" ]).or(base_podcasts.where(status: [ :published, :archived ])).order(created_at: :desc)
  end

  def show
  end

  def start_wizard
    # Clean up any existing abandoned drafts for this user first
    Current.user.podcasts.draft.where(name: [ nil, "" ]).destroy_all

    @podcast = Podcast.new(user: Current.user, status: :draft)
    @podcast.save!(validate: false)  # Skip validations for initial creation
    redirect_to podcast_wizard_path(@podcast.id, :overview), notice: "Started creating your podcast."
  end

  def new
    @podcast = Podcast.new
  end

  def create
    @podcast = Podcast.new(podcast_params.merge(user: Current.user, status: :draft))
    Rails.logger.debug "Saving podcast: #{@podcast.inspect}"
    if @podcast.save
      Rails.logger.debug "Podcast saved successfully, redirecting to wizard"
      redirect_to podcast_wizard_path(@podcast.id, :overview), notice: "Started creating your podcast."
    else
      Rails.logger.debug "Podcast save failed: #{@podcast.errors.full_messages.join(', ')}"
      render :new
    end
  end

  def edit
    @podcast.status = :draft unless @podcast.persisted? && @podcast.status == :published
  end

  def update
    @podcast.assign_attributes(podcast_params)
    if @podcast.save
      redirect_to @podcast, notice: "Podcast updated successfully"
    else
      render :edit
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
    params.require(:podcast).permit(:name, :description, :website_url, :primary_category, :secondary_category, :tertiary_category, :cover_art, media: [])
  end
end
