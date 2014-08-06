require 'nokogiri'
require 'uri'

class Html2Md
  class Document < Nokogiri::XML::SAX::Document
    
    attr_reader :markdown
    attr_accessor :relative_url

    def is_newline?(line)
      if line.is_a? String
        if /^\s+$/ =~ line
          true
        elsif  /^\[\[::HARD_BREAK::\]\]$/ =~ line
          true
        #elsif line.empty?
        #  true
        else
          false
        end
      else
        false
      end
    end

    def new_line
      @markdown << "\n" unless is_newline?( @markdown[-1] ) and is_newline?( @markdown[-2] )
    end

    def start_document
      @markdown = []
      @last_href = nil
      @allowed_tags = ['tr','td','th','table']
      @list_tree = []
      @last_cdata_length = 0
      @pre_block = false

    end
    
    def start_tag(name,attributes = [])
      if @allowed_tags.include? name
        "<#{name}>"
      else 
        ''
      end
    end

    def end_tag(name,attributes = [])
      if @allowed_tags.include? name
       "</#{name}>"
      else
        ''  
      end  
    end

    def start_element name, attributes = []
      #@markdown << name
      start_name = "start_#{name}".to_sym
      both_name = "start_and_end_#{name}".to_sym
      if self.respond_to?(both_name)
        self.send( both_name, attributes )
      elsif self.respond_to?(start_name)
        self.send( start_name, attributes ) 
      else
        @markdown << start_tag(name)
      end

    end

    def end_element name, attributes = []
      end_name = "end_#{name}".to_sym
      both_name = "start_and_end_#{name}".to_sym
      if self.respond_to?(both_name)
        self.send( both_name, attributes )
      elsif self.respond_to?(end_name)
        self.send( end_name, attributes ) 
      else
        @markdown << end_tag(name)
      end     
    end

    def start_strike(attributes)
      @markdown << "~~"
    end

    def end_strike(attributes)
      
      #Collapse Breaks
      while is_newline?( @markdown[-1] )
        @markdown.delete_at(-1)
      end

      #Collapse Space Before the emphasis
      @markdown.reverse!

      @markdown.each_index do |index|
        if @markdown[index].eql? '~~'
          
          count = 1
          while is_newline?(@markdown[index-count])
            @markdown.delete_at(index-count)    
          end

          @markdown[index-1].gsub!(/^\s+/,'')   
        end
      end
      @markdown.reverse!

      @markdown[-1].gsub!(/\s+$/,'')

      @markdown << '~~'


    end
    def start_hr(attributes)
      new_line
      @markdown << "********"
      new_line
      new_line
    end

    def end_hr(attributes)
      
    end

    def start_em(attributes)
      @markdown << "_"
    end

    def end_em(attributes)
      
      #Collapse Breaks
      while is_newline?( @markdown[-1] )
        @markdown.delete_at(-1)
      end


      #Collapse Space Before the emphasis
      @markdown.reverse!
      
      @markdown.each_index do |index|

        if @markdown[index].eql? '_' and not @markdown[index+1] =~ /\\$/
          
          count = 1
          while is_newline?(@markdown[index-count])
            @markdown.delete_at(index-count)    
          end

          @markdown[index-1].gsub!(/^\s+/,'')   
        end
      end
      @markdown.reverse!
      
      @markdown[-1].gsub!(/\s+$/,'')
      @markdown << '_'

      ###@markdown.gsub!(/((\[\[::HARD_BREAK::\]\])?(\s+)?)*_$/,'_')
    end

    def start_and_end_strong(attributes)
      @markdown << '**'
    end

    def start_br(attributes)
      new_line
      @markdown << "[[::HARD_BREAK::]]"
    end

    def end_br(attributes)

    end

    def start_p(attributes)
      
    end

    def end_p(attributes)
      new_line unless @list_tree[-1]
      new_line unless @list_tree[-1]
    end

    def start_h1(attributes)
      new_line
    end

    def end_h1(attributes)
      new_line
      @last_cdata_length.times do
        @markdown << "="
      end
      new_line
      new_line
    end

    def start_h2(attributes)
      new_line
    end

    def end_h2(attributes)
      new_line
      @last_cdata_length.times do
        @markdown << "-"
      end
      new_line
      new_line
    end

    def start_h3(attributes)
      new_line
      @markdown << "### "
    end

    def end_h3(attributes)
      new_line
      new_line
    end

    def start_a(attributes)
      attributes.each do | attrib |
        if attrib[0].downcase.eql? 'href'
          @markdown << '['
          @last_href = attrib[1]
        end
      end
    end

    def start_pre(attributes)
      @pre_block = true;
      new_line
      @markdown << "```"
      new_line
    end

    def end_pre(attributes)
      @pre_block = false;
      new_line
      @markdown << "```"
      new_line
    end

    def end_a(attributes)
      begin
        if @last_href and not (['http','https'].include? URI(URI.escape(@last_href)).scheme)
            begin 
              rp = URI(relative_url)
              rp.path = @last_href
              @last_href = rp.to_s
            rescue
            end
        end

        @markdown << "](#{@last_href})" if @last_href
        @last_href = nil if @last_href
      rescue 

      end

    end

    def start_ul(attributes)
      new_line
      @list_tree.push( { :type => :ul, :current_element => 0 } )
    end

    def end_ul(attributes)
      @list_tree.pop
      new_line unless @list_tree[-1]
    end

    def start_ol(attributes)
      new_line
      @list_tree.push( { :type => :ol, :current_element => 0 } )
    end

    def end_ol(attributes)
      @list_tree.pop
      @markdown << "\n" unless @list_tree[-1]
    end

    def start_li(attributes)
      
      if /^(-|\d+.)\s+$/ =~ @markdown[-2]
        @markdown.delete_at(-2)
        @markdown.delete_at(-3)
      end

      @markdown[-2].gsub! /^\s+(-|\d+.)\s+$/,''
      #Add Whitespace before the list item
      @list_tree.length.times do 
        @markdown << "  "
      end

      #Increment the Current Element to start at one
      @list_tree[-1][:current_element] += 1

     
      case @list_tree[-1][:type]
      when :ol
        @markdown << "#{ @list_tree[-1][:current_element] }. "
      when :ul
        @markdown << "- "
      end
        
    end

    def end_li(attributes)
      new_line if @markdown[-1] != "\n" and @markdown[-1] != 10
    end

    def start_img(attributes)
      alt  = src = ''
      attributes.each do |attrib|
        case attrib[0].downcase
        when 'alt'
          alt = "alt #{attrib[1]}"
        when 'src'
          src = attrib[1]
        end
      end
      alt = alt.eql?('') ? 'alt ' : alt
      @markdown << "![#{alt}](#{src})"
    end

    def end_img(attributes)
      @markdown << "</img>"
    end    

    def characters c
      #Escape character data with _
      c.gsub!('_','\_') unless @pre_block

      #Collapse all whitespace into spaces
      c.gsub!(/(\s+|\n|\r\n|\t)/, " ")

      
      if c.rstrip.lstrip.chomp != ""
        if @list_tree[-1]

          #Strip whitespace at the start of the character data
          c.gsub!(/\A(\r|\n|\s|\t)/,'')

          c.chomp!

          @last_cdata_length = c.chomp.length

          @markdown << c
        else
          @last_cdata_length = c.chomp.length
          @markdown << c
        end
      end
    end

    def end_document

      @markdown = @markdown.join('')
      #Replace All Ancor Links
      @markdown.gsub!(/\[.*\]\(#.*\)/,'')

      #Remove all extra space at the end of a line
      @markdown.gsub!(/ +$/,'')

      #Add Hard Breaks
      @markdown.gsub!(/\[\[::HARD_BREAK::\]\]/,"   \n")

      #Collapse Superfulious Hard Line Breaks
      #@markdown.gsub!(/(   \n+){1,}/,"   \n")

      #Collapse Superfulious Line Breaks
      @markdown.gsub!(/\n{2,}/,"\n\n")
    end

    
  end
end

