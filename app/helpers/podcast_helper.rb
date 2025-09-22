module PodcastHelper
  # Decide what color the wizard nav should be based on progress.
  #   Color: active = blue, complete = green, everything else = black
  #
  # @param step [String] Wizard step name
  #
  # @return [String] Tailwind CSS classes for color
  def wizard_step_color(step)
    case
    when past_step?(step)
      "text-green-600 dark:text-green-500"
    when current_step?(step)
      "text-blue-500 dark:text-blue-500"
    else
      "text-gray-500 dark:text-gray-400"
    end
  end
end
