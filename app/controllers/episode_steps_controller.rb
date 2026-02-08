class EpisodeStepsController < ApplicationController
  include Wicked::Wizard
  include SetPodcastAndEpisode
  include FileAttachable
  include EpisodeLabelable
  steps :overview, :assets, :details, :summary

  before_action :set_podcast
  before_action :set_episode
  before_action :set_steps
  before_action -> { authorize_resource_access(@episode) }

  def show
    session.delete(:validation_errors)
    render_wizard
  end

  # PATCH /podcasts/:podcast_id/episodes/:episode_id/wizard/assets
  def assets
    attach_files(@episode, :assets,
      success_redirect: podcast_episode_wizard_path(@podcast, @episode, :summary)
    ) do
      render turbo_stream: [
        turbo_stream.replace("current_assets",
          partial: "episode_steps/current_assets",
          locals: { episode: @episode }),
        turbo_stream.replace("summary_assets",
          partial: "episode_steps/summary_assets",
          locals: { episode: @episode, podcast: @podcast })
      ]
    end
  end

  # PATCH /podcasts/:podcast_id/episodes/:episode_id/wizard/raw_audio
  def raw_audio
    # Accept either file or files[]
    file = params[:file].presence || Array(params[:files]).first
    unless file.present?
      return render json: { error: "No file provided" }, status: :unprocessable_entity
    end
    @episode.raw_audio.purge_later if @episode.raw_audio.attached?
    @episode.raw_audio.attach(file)
    render json: { ok: true, filename: @episode.raw_audio.filename.to_s }, status: :ok
  end

  # DELETE /podcasts/:podcast_id/episodes/:episode_id/wizard/assets/:attachment_id
  def destroy_asset
    attachment = @episode.assets.attachments.find_by(id: params[:attachment_id])
    unless attachment
      respond_to do |format|
        format.json { render json: { error: "Not found" }, status: :not_found }
        format.turbo_stream { head :not_found }
        format.html { redirect_to podcast_episode_wizard_path(@podcast, @episode, :summary), alert: "Asset not found." }
      end
      return
    end
    attachment.purge_later
    respond_to do |format|
      format.json { render json: { ok: true }, status: :ok }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            "current_assets",
            partial: "episode_steps/current_assets",
            locals: { episode: @episode }
          ),
          turbo_stream.replace(
            "summary_assets",
            partial: "episode_steps/summary_assets",
            locals: { episode: @episode, podcast: @podcast }
          )
        ]
      end
      format.html do
        redirect_to podcast_episode_wizard_path(@podcast, @episode, :summary), notice: "Asset deleted."
      end
    end
  end

  # DELETE /podcasts/:podcast_id/episodes/:episode_id/wizard/raw_audio
  def destroy_raw_audio
    if @episode.raw_audio.attached?
      @episode.raw_audio.purge_later
    end
    render json: { ok: true }, status: :ok
  end

  def update
    session.delete(:validation_errors)

    filtered_params, assets_to_attach = filter_and_extract_params
    @episode.assign_attributes(filtered_params) if filtered_params.present?

    auto_assign_episode_number

    if valid_for_current_step?
      if @episode.save(validate: false)
        attach_pending_assets(assets_to_attach)
        process_episode_asset_labels(@episode)
        process_episode_cover_art_label(@episode)
        navigate_after_update
      else
        render step
      end
    else
      session[:validation_errors] = @episode.errors.full_messages
      render step
    end
  end

  private

  def set_steps
    @steps = steps
  end

  def filter_and_extract_params
    return [ nil, nil ] unless params[:episode].present?

    filtered = episode_params
    assets = nil

    # Extract assets for separate attachment (has_many_attached doesn't work well with assign_attributes)
    if filtered[:assets].present?
      assets = filtered[:assets].reject(&:blank?)
      filtered = filtered.except(:assets)
    end

    # Don't overwrite existing files with blank params
    filtered = filtered.except(:raw_audio) if filtered[:raw_audio].blank?
    filtered = filtered.except(:cover_art) if filtered[:cover_art].blank?

    # Clear cover art if removal was requested
    if params[:episode][:remove_cover_art].to_s == "1"
      @episode.cover_art.purge_later if @episode.cover_art.attached?
    end

    # Preserve existing episode number if left blank
    if filtered.key?(:number) && filtered[:number].to_s.strip.blank?
      filtered = filtered.except(:number)
    end

    # Join output formats array into comma-separated string for storage
    if filtered[:output_formats].is_a?(Array)
      filtered[:output_formats] = filtered[:output_formats].reject(&:blank?).join(",")
    end

    [ filtered, assets ]
  end

  def auto_assign_episode_number
    return unless step == :summary && @episode.number.blank?

    next_number = (@podcast.episodes.where.not(id: @episode.id).maximum(:number) || 0) + 1
    @episode.number = next_number
  end

  def valid_for_current_step?
    case step
    when :overview then @episode.valid?(:overview_step)
    when :details  then @episode.valid?(:details_step)
    when :summary  then @episode.valid?(:overview_step) & @episode.valid?(:details_step)
    else true
    end
  end

  def attach_pending_assets(assets)
    return unless assets.present?

    assets.each { |signed_id| @episode.assets.attach(signed_id) }
  end

  def navigate_after_update
    if step == steps.last
      redirect_to_finish_wizard
    else
      redirect_to next_wizard_path
    end
  end

  def episode_params
    params.require(:episode).permit(
      :name,
      :number,
      :description,
      :links,
      :release_date,
      :format,
      :notes,
      :guests,
      :output_formats,
      :deliver_mp3,
      :deliver_mp4,
      :deliver_mov,
      :raw_audio,
      :cover_art,
      assets: [],
      output_formats: []
    )
  end

  def redirect_to_finish_wizard
    redirect_to podcast_episode_path(@podcast, @episode), notice: "Episode created successfully."
  end
end
