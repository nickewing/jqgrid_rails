require 'jqgrid/template_handler'
require 'jqgrid/action_view'
require 'jqgrid/action_controller'

class ActionView::Base
  include JqGrid::ActionView
end

class ActionController::Base
  include JqGrid::ActionController
end