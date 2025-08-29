module ApplicationHelper
  def sidebar_link_class(path, controller_name = nil)
    base_classes = "flex items-center px-4 py-3 text-gray-700 rounded-lg hover:bg-gray-100 transition-colors"

    if controller_name && controller_name == controller.controller_name
      "#{base_classes} bg-red-50 text-red-600 underline"
    elsif current_page?(path)
      "#{base_classes} bg-red-50 text-red-600 underline"
    else
      base_classes
    end
  end
end
