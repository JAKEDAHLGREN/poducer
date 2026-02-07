class Producer::EpisodesController < ApplicationController
  include FileAttachable

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
    # Allow producer to upload edited audio, deliverables, and update episode
    if @episode.update(episode_params)
      process_deliverable_labels
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
    attach_files(@episode, :deliverables,
      success_redirect: producer_episode_path(@episode),
      error_redirect: producer_episode_path(@episode)
    ) do
      render turbo_stream: turbo_stream.replace("producer_assets",
        partial: "producer/episodes/deliverables",
        locals: { episode: @episode })
    end
  end

  private

  def set_episode
    @episode = Episode.find(params[:id])
  end

  def episode_params
    params.require(:episode).permit(:edited_audio, :notes, deliverables: [])
  end

  def process_deliverable_labels
    labels = deliverable_label_hash
    json_labels = deliverable_label_json
    return if labels.blank? && json_labels.blank?

    @episode.deliverables.attachments.each do |attachment|
      filename = attachment.filename.to_s
      labels[attachment.id.to_s] = json_labels[filename] if json_labels[filename].present?
    end

    @episode.deliverables.attachments.each do |attachment|
      label_value = labels[attachment.id.to_s].presence || labels[attachment.blob.id.to_s].presence
      next if label_value.blank?

      new_metadata = attachment.blob.metadata.merge("label" => label_value.to_s.strip)
      attachment.blob.update!(metadata: new_metadata)
    end
  rescue StandardError
    # Silently ignore metadata update errors
  end

  def deliverable_label_hash
    raw = params[:deliverable_labels].presence || params.dig(:episode, :deliverable_labels).presence
    return {} if raw.blank?

    raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
  rescue StandardError
    {}
  end

  def deliverable_label_json
    raw = params[:deliverable_labels_json].presence || params.dig(:episode, :deliverable_labels_json).presence
    return {} if raw.blank?

    JSON.parse(raw.to_s)
  rescue JSON::ParserError
    {}
  end
end
