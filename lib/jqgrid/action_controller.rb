module JqGrid
  module ActionController
    attr_reader :_jqgrid_options
    
    def jqgrid(options)
      @_jqgrid_options = options
    end
  end
end