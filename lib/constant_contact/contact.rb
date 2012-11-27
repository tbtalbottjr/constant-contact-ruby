module ConstantContact
  class Contact < BaseResource

    attr_reader :uid, :contact_lists, :original_xml

    def initialize( params={}, orig_xml='', from_contact_list=false ) #:nodoc:
      return false if params.empty?
      @uid = params['id'].split('/').last
      @original_xml = orig_xml
      @contact_lists = []

      if from_contact_list
        fields = params['content']['ContactListMember']
      else
        fields = params['content']['Contact']
      end

      if lists = fields.delete( 'ContactLists' )
        if lists['ContactList'].is_a?( Array )
          @contact_lists = lists['ContactList'].collect { |list| list['id'].split('/').last }
        else
          @contact_lists << lists['ContactList']['id'].split('/').last
        end
      end

      fields.each do |k,v|
        underscore_key = underscore( k )
        
        instance_eval %{
          @#{underscore_key} = "#{v}"

          def #{underscore_key}
            @#{underscore_key}
          end
        }
      end

    end # def initialize

    # Update a single contact record
    #
    # NOTE: you cannot update a Contact's ContactList subscriptions through
    # this method.  Use the appropriate ContactList methods instead
    #
    def update_attributes!( params={} )
      return false unless full_record? # TODO: raise some kind of specific error here

      params.each do |key,val|
        self.instance_variable_set("@#{key.to_s}", val)
      end

      data = ConstantContact.put( "/contacts/#{self.uid}", :body => self.send(:to_xml) )
      if data.code == 204 # success
        return true
      else
        raise create_exception(data)
      end
    end

    # Add user to a contact list
    def add_to_list!( list_id, options={} )
      list_id = list_id.to_s
      xml = update_contact_lists( *(self.contact_lists + [list_id]) )

      # FIXME: clean up the following code - it appears in 3 methods in this class!
      options.merge!({ :body => xml })
      data = ConstantContact.put( "/contacts/#{self.uid}", options )

      if data.code == 204 # success
        self.contact_lists << list_id unless self.contact_lists.include?( list_id )
        return true
      else
        raise create_exception(data)
      end
    end

    # Remove user from a contact list
    def remove_from_list!( list_id, options={} )
      list_id = list_id.to_s
      xml = update_contact_lists( *(self.contact_lists - [list_id]) )

      # FIXME: clean up the following code - it appears in 3 methods in this class!
      options.merge!({ :body => xml })
      data = ConstantContact.put( "/contacts/#{self.uid}", options )
      
      if data.code == 204 # success
        self.contact_lists.delete( list_id )
        return true
      else
        raise create_exception(data)
      end
    end

    # Set a users contact lists
    def replace_contact_lists!( *lists )
      xml = update_contact_lists( *lists )

      # FIXME: clean up the following code - it appears in 3 methods in this class!
      options = { :body => xml }
      data = ConstantContact.put( "/contacts/#{self.uid}", options )
      
      if data.code == 204 # success
        @contact_lists = lists.map { |l| l.to_s }
        return true
      else
        raise create_exception(data)
      end
    end

    # Opt-out from all contact lists
    #
    # Contact will be removed from all lists and become a member of the 
    # Do-Not_Mail special list
    def opt_out!( options={} )
      data = ConstantContact.delete( "/contacts/#{self.uid}", options )

      if data.code == 204
        @contact_lists = []
        return true
      else
        raise create_exception(data)
      end
    end

    # Opt-in a user who has previously opted out
    #--
    # FIXME: this isn't currently working.  Currently I keep getting a 403-Forbidden response
    #        should this really even be in the API wrapper at all?
    def opt_in!( *lists )
      # # NOTE: same as replace_contact_lists but must set to ACTION_BY_CONTACT
      # xml = update_contact_lists( *lists ).gsub( /<\/ContactLists>/, %Q(<OptInSource>ACTION_BY_CONTACT</OptInSource>\n\t</ContactLists>) )

      # # FIXME: clean up the following code - it appears in 3 methods in this class!
      # options = { :body => xml }
      # data = ConstantContact.put( "/contacts/#{self.uid}", options )
      # 
      # if data.code == 204 # success
      #   @contact_lists = lists.map { |l| l.to_s }
      #   return true
      # else
      #   return false # probably should raise an error here instead
      # end
    end

    # Get a summary list all contacts
    def self.all( options={} )
      contacts = []
      link = '/contacts'
      paged = false
      if options['next_link']
        full_link = options.delete('next_link')
        link += "?#{full_link.split('?').last}"
      end
      if options['paged']       
        paged = options.delete('paged')
      end
      
      data = ConstantContact.get( link, options )
      return contacts if ( data.nil? or data.empty? )
      entries = data['feed']['entry']
      return contacts if ( entries.nil? or entries.empty? )
      if entries.kind_of?(Array)      
        entries.each do |entry|
          contacts << new( entry )
        end
      else
        contacts << new( entries )
      end

      if feed_has_next_link?(data['feed'])
        next_link = find_next_link data['feed']
        if paged
          contacts << {'next_link' => next_link}
        else
          contacts += self.all(options.merge!('next_link' => next_link))
        end
      end

      contacts
    end
    
    # Add a new contact
    #
    # Required data fields:
    # * EmailAddress => String
    # * ContactLists => Array of list IDs
    #
    # Options data fields:
    # * EmailType
    # * FirstName
    # * MiddleName
    # * LastName
    # * JobTitle
    # * CompanyName
    # * HomePhone
    # * WorkPhone
    # * Addr1
    # * Addr2
    # * Addr3
    # * City
    # * StateCode => Must be valid US/Canada Code (http://ui.constantcontact.com/CCSubscriberAddFileFormat.jsp#states)
    # * StateName
    # * CountryCode = Must be valid code (http://constantcontact.custhelp.com/cgi-bin/constantcontact.cfg/php/enduser/std_adp.php?p_faqid=3614)
    # * CountryName
    # * PostalCode
    # * SubPostalCode
    # * Note
    # * CustomField[1-15]
    # * OptInSource
    # * OptOutSource
    # 
    def self.add( data={}, opt_in='ACTION_BY_CUSTOMER', options={} )
      xml = build_contact_xml_packet( data, opt_in )

      options.merge!({ :body => xml })
      data = ConstantContact.post( "/contacts", options )

      # check response.code
      if data.code == 201 # Entity Created
        return new( data['entry'] )
      elsif data.code == 400 # Invalid entry
        puts "Message: #{data.body}"
        return nil
      else
        # data.code == 409 # Conflict ( probably a duplicate )
        raise create_exception(data)  
      end
    end
    
    # Get detailed record for a single contact by id
    def self.get( id, options={} )
      data = ConstantContact.get( "/contacts/#{id.to_s}", options )
      return nil if ( data.nil? or data.empty? )
      new( data['entry'], data.body )
    end
    
    # Search for a contact by last updated date
    # 
    # Valid options:
    # * :updated_since => Time object
    # * :list_type => One of 'active'|'removed'|'do-not-mail'
    #
    # def self.search_by_date( options={} )
    # end

    # Search for a contact by email address
    # 
    # @param [String] email => "user@example.com"
    #
    def self.search_by_email( email )
      data = ConstantContact.get( '/contacts', :query => { :email => email.downcase } )
      return false if ( data.nil? )
      
      if data.code == 500
        raise Error.new(extract_error_msg(data))
      else
        params = data['feed']['entry']
        return false if ( params.nil? )
        new( params )
      end
    end

    # Returns the objects API URI
    def self.url_for( id )
      "#{ConstantContact.base_uri}/contacts/#{id}"
    end

    # convert a full Contact record into a Hash
    def to_hash
      return {} unless full_record?

      contact_hash = {}
      self.instance_variables.each do |ivar|
        var = ivar.gsub(/@/,'').to_sym
        contact_hash[var] = self.instance_variable_get(ivar)
      end
      contact_hash
    end

    private
    
    def contact_list_element(list); %Q(        <ContactList id="#{ContactList.url_for( list )}" />\n); end

    def update_contact_lists( *lists )
      str = %Q(<ContactLists>\n)
      lists.each do |list|
        if list.kind_of? Array
          list.each do |l|
            str << contact_list_element(l) unless l.empty?
          end
        else
          str << contact_list_element(list) unless list.empty?
        end
      end
      str << %Q(      </ContactLists>)

      # self.original_xml.gsub(/<ContactLists>.*<\/ContactLists>/m, str)
      if self.original_xml =~ /<ContactLists>.*<\/ContactLists>/m
        self.original_xml.gsub( /#{$&}/, str)
      else
        self.original_xml.gsub( /<\/Contact>/m, "#{str}\n</Contact>" )
      end
    end

    def self.build_contact_xml_packet( data={}, opt_in='ACTION_BY_CUSTOMER' )
      xml = <<EOF
<entry xmlns="http://www.w3.org/2005/Atom">
  <title type="text"> </title>
  <updated>#{Time.now.strftime("%Y-%m-%dT%H:%M:%S.000Z")}</updated>
  <author> </author>
  <id>data:,none</id>
  <summary type="text">Contact</summary>
  <content type="application/vnd.ctct+xml">
    <Contact xmlns="http://ws.constantcontact.com/ns/1.0/">
EOF
      
      data.each do |key, val|
        node = camelize(key.to_s)

        if key == :contact_lists
          xml << %Q(      <ContactLists>\n)
          val.each do |list_id|
            xml<< %Q(       <ContactList id="#{ContactList.url_for( list_id )}" />\n)
          end
          xml << %Q(      </ContactLists>\n)
        else
          xml << %Q(      <#{node}>#{val}</#{node}>\n)
        end
      end

      xml += <<EOF
      <OptInSource>#{opt_in}</OptInSource>
    </Contact>
  </content>
</entry>
EOF
      xml
    end # def build_contact_xml_packet

    # Is this a full contact record?
    def full_record?
      !self.contact_lists.empty?
    end

    # convert a full Contact record into XML format
    def to_xml
      return nil unless full_record?

      do_not_process =  [ "@contact_lists", "@original_source", "@original_xml", "@uid", "@xmlns" ]

      xml = self.original_xml

      self.instance_variables.each do |ivar|
        next if do_not_process.include?( ivar )

        var = camelize( ivar.gsub(/@/,'') )

        xml.gsub!( /<#{var}>(.*)<\/#{var}>/ , "<#{var}>#{self.instance_variable_get(ivar)}</#{var}>" )
      end

      # replace <updated> node with current time
      xml.gsub( /<updated>.*<\/updated>/, Time.now.strftime("%Y-%m-%dT%H:%M:%S.000Z") )

      xml
    end

  end # class Contact
end # module ConstantContact
