class Producer::EpisodesController < ApplicationController
  before_action :ensure_producer
  before_action :set_episode, only: [ :show, :start_editing, :complete_editing, :update ]

  def index
    @episodes = Episode.includes(:podcast, podcast: :user).where(status: [ :edit_requested, :editing, :awaiting_user_review, :ready_to_publish ]).order(updated_at: :desc)

    @edit_requested_episodes = @episodes.select(&:edit_requested?)
    @editing_episodes = @episodes.select(&:editing?)
    @awaiting_user_review_episodes = @episodes.select(&:awaiting_user_review?)
    @ready_to_publish_episodes = @episodes.select(&:ready_to_publish?)
  end

  def show
    # Show episode details for producer
  end

  def update
    # Allow producer to upload edited audio and update episode
    if @episode.update(episode_params)
      redirect_to producer_episode_path(@episode), notice: "Episode updated successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def start_editing
    if @episode.start_editing!
      redirect_to producer_episode_path(@episode), notice: "Started editing episode."
    else
      redirect_to producer_episodes_path, alert: "Unable to start editing episode."
    end
  end

  def complete_editing
    # Allow submission if producer uploaded at least one deliverable or an edited audio file
    unless (@episode.deliverables.attached? || @episode.edited_audio.attached?)
      return redirect_to producer_episode_path(@episode), alert: "Please upload at least one deliverable before submitting for review."
    end

    if @episode.complete_editing!
      redirect_to producer_episodes_path, notice: "Episode editing completed."
    else
      redirect_to producer_episode_path(@episode), alert: "Unable to complete episode editing."
    end
  end

  # PATCH /producer/episodes/:id/upload_assets
  def upload_assets
    incoming = params[:files].presence || params[:file].presence
    unless incoming
      respond_to do |format|
        format.json { render json: { error: "No files provided" }, status: :unprocessable_entity }
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to producer_episode_path(@episode), alert: "No files provided." }
      end
      return
    end

    Array(incoming).each { |file| @episode.deliverables.attach(file) }

    respond_to do |format|
      format.json { render json: { ok: true, count: @episode.deliverables.count }, status: :ok }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "producer_assets",
          partial: "producer/episodes/deliverables",
          locals: { episode: @episode }
        )
      end
      format.html { redirect_to producer_episode_path(@episode), notice: "Files uploaded." }
    end
  end

  private

  def set_episode
    @episode = Episode.find(params[:id])
  end

  def episode_params
    params.require(:episode).permit(:edited_audio, :notes, deliverables: [])
  end
end
