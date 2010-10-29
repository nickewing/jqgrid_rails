class JQGRID < ::ActionView::TemplateHandler
  
  def initialize(view)
    @view = view
    @controller = view.controller # used for attr_reader
  end

  def render(template, local_assigns = {})
    @controller.headers["Content-Type"] = 'application/json'
    
    grid = GridData.new(@controller)
    
    # Retrieve controller variables
    @controller.instance_variables.each do |v|
      instance_variable_set(v, @controller.instance_variable_get(v))
    end
    
    # run template
    eval template.source, nil, ''
    
    grid.to_json
  end
  
  class GridData
    # include standard view helpers
    include ApplicationHelper
    include ActionView::Helpers
    
    attr_reader :controller # used for delegate
    delegate :url_for, :to => :controller # fix for url_for problem with link_to
    
    def initialize(controller)
      @controller = controller
      @opts = @controller._jqgrid_options
      @find_opts = {}
    end
    
    # template method
    def field(name, opts = {}, &block)
      @columns ||= {}
      opts[:field] = name unless opts[:field]
      @columns[name] = [process_col_opts(opts), block]
    end
    
    # build jqGrid json
    def to_json
      if columns = params[:columns]
        columns = columns.split(',')
      else
        raise "No column's provided to show."
      end
      
      paginated_hash(columns).to_json
    end
    
    protected
      
      def params
        @controller.params
      end
      
      def paginated_hash(columns)
        total_rows, total_pages, page, items = fetch_paginated_items(columns)

        # build final jgGrid structure
        {
          :records => total_rows,
          :page    => page,
          :total   => total_pages,
          :rows    => row_hashes(items, columns)
        }
      end
      
      def fetch_paginated_items(columns)
        # build conditions for find
        @source = @opts[:source]

        build_search_conditions
        
        @source = @source.scoped(:joins => @find_opts[:joins])

        # calculate total pages of items
        rows_shown = params[:rows].to_i
        total_rows = @source.count
        total_pages = calc_total_pages(total_rows, rows_shown)
        
        order = build_order_clause(params[:sort_column], params[:sort_order])

        # determine current page
        page = calc_current_page(total_pages)

        items = @source.all(
          :limit  => rows_shown,
          :offset => (page - 1) * rows_shown,
          :order  => order
        )
        
        [total_rows, total_pages, page, items]
      end

      def build_search_conditions
        field  = params[:searchField]
        op     = params[:searchOper]
        str    = params[:searchString]

        return unless params[:_search]
        
        if field and op and str and col = @columns[field.to_sym]
          field = col[0][:search_by_str] || col[0][:field_str]

          expr = "ILIKE ?"

          case op
          when 'eq' # equal to
            # do nothing
          when 'bw' # begins with
            str  = "#{str}%"    
          when 'ne' # not equal
            expr = "NOT #{expr}"
          when 'ew' # ends with
            str = "%#{str}"
          when 'cn' # contains
            str = "%#{str}%"
          end

          query = "#{field} #{expr}"
          vals  = [str]
        else
          query = []
          vals  = []

          @columns.each_pair do |key, col|
            if str = params[key.to_s]
              field = col[0][:search_by_str] || col[0][:field_str]

              query << "#{field} ILIKE ?"
              vals  << "%#{str}%"
            end
          end

          query = query.join(' AND ')
        end

        vals.unshift(query)

        @source = @source.scoped(:conditions => vals)
      end
      
      def calc_total_pages(total_rows, rows_shown)
        total_pages = (total_rows.to_f / rows_shown).ceil
        
        [total_pages, 1].max
      end
      
      def calc_current_page(total_pages)
        page = params[:page].to_i > total_pages ?
          total_pages :
          params[:page].to_i
        
        [page, 1].max
      end
      
      def build_order_clause(field, order)
        if !field.blank? and col = @columns[field.to_sym]
          order_dir = order if %w(asc desc).include? order
          
          if col[0][:order_by]
            order_col = col[0][:order_by_str]
          else
            order_col = col[0][:field_str] || field
          end

          order_col + ' ' + order_dir if order_col and order_dir
        end
      end
      
      def get_scoped_item(item, method)
        method ? item.send(method) : item
      end
      
      def row_hashes(items, columns)
        items.map do |item|
          m_item = get_scoped_item(item, @opts[:global_method])

          # row hash representation
          {
            :id   => m_item.id,
            :cell => item_column_values(m_item, columns)
          }
        end
      end
      
      # Get each field value, returning an array of the row's column values
      def item_column_values(item, columns)
        columns.map do |col|
          column_value(item, col) or '-'
        end
      end
      
      def column_value(item, col)
        return unless col = @columns[col.to_sym]
        
        if col[1]
          # if block, call block with scoped item
          col[1].bind(self).call(item)
        else
          # send item the column's field if no block
          send_method_path(item, col[0][:display_field] || col[0][:field])
        end
      rescue => e
        puts e
        e.backtrace.each{|l| puts l}
        '[Error]'
      end
      
      # find table from source association
      def ref_table(method, source, col) 
        (method ?
          source.reflect_on_association(method).klass :
          source).table_name
      end
      
      def path_sql_field(item, path)
        p = ([path] unless path.is_a? Array) || path.dup
        p.unshift(@opts[:global_method]) if @opts[:global_method]
        if p.size > 1
          append_inc(p[0 .. p.size - 2])
          p[0 .. p.size - 2].each do |e|
            ref = item.reflect_on_association(e)
            return path.to_s unless ref # failed => return original path
            item = ref.klass
          end
        end
        item.table_name + '.' + p.last.to_s
      end
      
      def process_col_opts(opts)
        fields = [:field, :order_by, :search_by]
        opts.each_pair do |k, v|
          key = (k.to_s + '_str').to_sym
          opts[key] = path_sql_field(@opts[:source], v) if fields.include? k
        end
      end
      
      def send_method_path(item, path)
        p = ([path] unless path.is_a? Array) || path.dup
        p.inject(item) do |item, i|
          ret = item.send(i)
          raise "Item #{item.inspect} returned nil to method '#{i}'" unless
            ret != nil
          ret
        end
      end
      
      def append_inc(path)
        @find_opts[:joins] ||= []
        inc = path.reverse.reduce([]) {|l, r| {r => l}}
        @find_opts[:joins] << inc unless @find_opts[:joins].include? inc
      end
  end
  
  ActionController::Routing::Routes.named_routes.install JQGRID::GridData
end
