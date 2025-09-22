module PodcastHelper
  # Decide what color the wizard nav should be based on progress.
  #
  # @param step [String] Wizard step name
  #
  # @return [String] Tailwind CSS classes for color
  def wizard_step_color(step)
    case
    when past_step?(step)
      "text-gray-800 font-medium"
    when current_step?(step)
      "text-gray-900 font-bold"
    else
      "text-gray-500 font-medium"
    end
  end

  # Generate the appropriate circle for a wizard step based on its state
  #
  # @param step [String] Wizard step name
  #
  # @return [String] HTML string containing the circle element
  def wizard_step_circle(step)
    if past_step?(step)
      # Dark filled circle for completed steps
      content_tag :div, "", class: "w-8 h-8 bg-gray-600 rounded-full border border-gray-900 z-2"
    elsif current_step?(step)
      # Highlighted circle for current step
      content_tag :div, "", class: "w-8 h-8 bg-orange-500 rounded-full border border-gray-800 z-2"
    else
      # Light gray circle for future steps
      content_tag :div, "", class: "w-8 h-8 bg-gray-300 rounded-full border border-gray-400 z-2"
    end
  end

  # Generate connecting line between steps
  #
  # @param is_last [Boolean] Whether this is the last step
  #
  # @return [String] HTML string containing the connecting line
  def wizard_step_line(is_last = false)
    return "" if is_last
    content_tag :div, "", class: "flex-1 h-0.25 bg-gray-800 -mx-6 mb-8"
  end
end
