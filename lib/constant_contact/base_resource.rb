module ConstantContact
  class BaseResource #:nodoc:
    
    private 

    def self.camelize( string )
      string.split( /[^a-z0-9]/i ).map{ |w| w.capitalize }.join
    end

    def camelize( string )
      BaseResource.camelize( string )
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
    
  end
end
