require 'jqgrid'

Mime::Type.register 'application/json', :json

ActionView::Template.register_template_handler :jqgrid, JQGRID
ActionView::Template.exempt_from_layout :jqgrid