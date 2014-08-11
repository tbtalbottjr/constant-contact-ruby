module ConstantContact
  class BaseResource #:nodoc:
    
    private 

    def self.camelize( string )
      string.split( /[^a-z0-9]/i ).map{ |w| w.capitalize }.join
    end

    def camelize( string )
      BaseResource.camelize( string )
    end

    def create_exception(data)
      self.class.create_exception(data)
    end

    def self.underscore( string )
      string.to_s.gsub(/::/, '/').gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').gsub(/([a-z\d])([A-Z])/,'\1_\2').tr("-", "_").downcase
    end
    
    def underscore( string )
      BaseResource.underscore( string )
    end
    
    def self.feed_has_next_link?(feed)
      !find_next_link(feed).nil?
    end

    def self.find_next_link(feed)
      feed['link'].collect { |link| link['href'] if link["rel"] && link["rel"] == 'next' }.compact.first
    end
    
    def self.extract_error_msg(data)
      begin
        errmsg = "HTTP Status Code: #{data.code}, message: #{data.message}"
      rescue
        errmsg = data.body
      end
      errmsg
    end
    
    def self.create_exception(data)
      begin
        err = Error.new(data.message, data.code)
      rescue
        err = Error.new(data.body, data.code)
      end
      err
    end
    
    def compact_simple_node(node)
      new_node = {}
      node.each do |k,v|
        new_node[k] = v['__content__'].strip unless v['__content__'].nil?
      end
      return new_node
    end
  end
end
