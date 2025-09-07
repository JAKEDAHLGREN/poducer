module EpisodesHelper
  def episode_status_badge(status)
    status_config = {
      "draft" => { text: "Draft", bg: "bg-gray-100", text_color: "text-gray-800" },
      "edit_requested" => { text: "Edit Requested", bg: "bg-blue-100", text_color: "text-blue-800" },
      "editing" => { text: "Editing", bg: "bg-yellow-100", text_color: "text-yellow-800" },
      "episode_complete" => { text: "Episode Complete", bg: "bg-green-100", text_color: "text-green-800" },
      "archived" => { text: "Archived", bg: "bg-red-100", text_color: "text-red-800" }
    }

    config = status_config[status] || { text: status.humanize, bg: "bg-gray-100", text_color: "text-gray-800" }

    content_tag :span, config[:text],
      class: "inline-flex items-center px-3 py-1 rounded-full text-sm font-medium #{config[:bg]} #{config[:text_color]}"
  end
end
