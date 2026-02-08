# Handles persisting asset and cover_art labels to blob metadata for episodes.
# Include in any controller that updates episodes and submits label params
# (e.g. EpisodeStepsController, EpisodesController).
# Label params can be submitted at top level (asset_labels, cover_art_labels)
# or under params[:episode] depending on form structure.
module EpisodeLabelable
  extend ActiveSupport::Concern

  private

  def process_episode_asset_labels(episode)
    labels = episode_label_hash(:asset_labels) || {}
    json_labels = episode_label_json(:asset_labels_json) || {}
    return if labels.blank? && json_labels.blank?

    episode.assets.attachments.each do |attachment|
      filename = attachment.filename.to_s
      labels[attachment.id.to_s] = json_labels[filename] if json_labels[filename].present?
    end

    episode.assets.attachments.each do |attachment|
      label_value = labels[attachment.id.to_s].presence || labels[attachment.blob.id.to_s].presence
      next if label_value.blank?

      update_blob_label(attachment.blob, label_value)
    end
  end

  def process_episode_cover_art_label(episode)
    return unless episode.cover_art.attached?

    labels = episode_label_hash(:cover_art_labels)
    json_labels = episode_label_json(:cover_art_labels_json)
    blob = episode.cover_art.blob
    attachment = episode.cover_art.attachment
    return unless blob && attachment

    labels[blob.id.to_s] = json_labels[blob.filename.to_s] if json_labels[blob.filename.to_s].present?

    label_value = labels[attachment.id.to_s].presence || labels[blob.id.to_s].presence
    return if label_value.blank?

    update_blob_label(blob, label_value)
  end

  # Read label hash from top-level or params[:episode]
  def episode_label_hash(key)
    raw = params[key].presence || params.dig(:episode, key).presence
    return {} if raw.blank?

    raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
  rescue StandardError
    {}
  end

  # Read label JSON (filename => label) from top-level or params[:episode]
  def episode_label_json(key)
    raw = params[key].presence || params.dig(:episode, key).presence
    return {} if raw.blank?

    JSON.parse(raw.to_s)
  rescue JSON::ParserError
    {}
  end

  def update_blob_label(blob, label_value)
    return if blob.blank? || label_value.blank?

    new_metadata = blob.metadata.merge("label" => label_value.to_s.strip)
    blob.update!(metadata: new_metadata)
  rescue StandardError
    # Silently ignore metadata update errors
  end
end
