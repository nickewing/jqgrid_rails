module JqGrid
  module ActionView
    
    def jqgrid(options = {}, &block)
      grid = Grid.new
      grid.build(options, block)
    end
  
    class Grid
    
      def map_keys(hash, keys)
        keys.each do |k, v|
          (hash[v] = hash.delete(k)) if hash[k] != nil
        end
        hash
      end
    
      def build(opts, block)
        block.call(self)
      
        id = opts.delete(:id).to_sym
        filterToolbar = opts.delete(:filterToolbar) unless opts[:filterToolbar].blank?
      
        opts[:with] = {} unless opts[:with]
        opts[:with].merge!({:columns => @column_names.join(',')})
      
      
        if opts[:toolbar]
          opts[:toolbar] = [true, opts[:toolbar] == :bottom ? 'bottom' : 'top']
        end
      
        option_map = {
          :with               => :postData,
          :multi_select       => :multiselect,
          :rows_shown         => :rowNum,
          :rows_shown_options => :rowList,
          :image_path         => :imgpath,
          :collapsable        => :hidegrid,
          :load_complete      => :loadComplete,
          :grid_complete      => :gridComplete,
          :before_request     => :beforeRequest,
          :sort_name          => :sortname,
          :sort_order         => :sortorder
        }
      
        opts = map_keys(opts, option_map)
      
        js_opts = [
          :loadComplete,
          :gridComplete,
          :beforeRequest
        ]
      
        js_opts_set = {
          :pager => "$('#jqGrid_pager')"
        }
      
        js_opts.each do |opt|
          js_opts_set[opt] = opts.delete(opt) if opts[opt]
        end
      
        # cannot use to_json for these because function calls would be turned
        # into strings
        js_opts = js_opts_set.map{|k,v| %|"#{k}":#{v}|}.join(',')
      
        build_opts = {
          :datatype     => 'json',
          :colNames     => @column_headers,
          :colModel     => @column_data,
          :rowNum       => 10,
          :rowList      => [10, 20, 30],
          :prmNames     => {
            :page   => "page",
            :rows   => "rows",
            :sort   => "sort_column",
            :order  => "sort_order"
          },
          :imgpath      => '/stylesheets/jqGrid/steel/images',
          :viewrecords  => true,
          :height       => 'auto'
        }.merge!(opts).to_json
      
        build_opts[0] = '{' + js_opts + ','
      
        ret =<<-tbl
        <script type="text/javascript">
        jQuery().ready(function ($) {
          var opts = #{build_opts};
        
          $("##{id}_table")
            .jqGrid(opts)
            .navGrid('##{id}_pager',
              {edit:false, add:false, del:false},{},{},{},
              {width:582, height: 50, sopt: ['bw','eq','ne','cn']});
        tbl
        
        if filterToolbar
          ret = ret + <<-tbl
                      jQuery("##{id}_table").jqGrid().filterToolbar({searchOnEnter: false});
                      tbl
        end
        ret = ret + <<-tbl
        });
        
        </script>
        <div id="#{id}_cont">
          <table id="#{id}_table" class="scroll" cellpadding="0" cellspacing="0"></table>
          <div id="#{id}_pager" class="scroll" style="text-align:center;"></div>
        </div>
        tbl
      end
    
      def column(name, options = {})
        @column_headers ||= []
        @column_data ||= []
        @column_names ||= []
      
        # map our setting names to their stupid ones
      
        option_map = {
          :searchable => :search
        }
      
        options = map_keys(options, option_map)
        
        options[:name] = name.to_s
      
        options[:title] = options[:name].capitalize \
          if options[:name] and not options[:title]
            
        if !options[:editoptions].blank?
          # Generate jqGrid expected value string, clear out options, store string
          values = "#{get_sub_options(options[:editoptions])}"
          options[:editoptions].clear
          options[:editoptions][:value] = values
        end            
      
        @column_headers << options.delete(:title)
        @column_names << options[:name]
        @column_data << options
      end
private      
      def get_sub_options(editoptions)
        options = ""
        editoptions.each do |v|
          options << "#{v[0]}:#{v[1]};"
        end
        options.chop! << ""
      end    
    end
  
  end
end