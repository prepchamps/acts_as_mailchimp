require 'xmlrpc/client'
module Terra
  module Acts #:nodoc:
    module MailChimp #:nodoc:
      class MailChimpConfigError < StandardError; end
      class MailChimpConnectError < StandardError; end

      def self.included(base)
        base.extend ClassMethods
        mattr_reader :monkeybrains
        begin
          @@monkeybrains = YAML.load(File.open("#{RAILS_ROOT}/config/monkeybrains.yml"))[RAILS_ENV].symbolize_keys        
        end
      end

      module ClassMethods
        def acts_as_mailchimp(opts={})
          include Terra::Acts::MailChimp::InstanceMethods
          extend Terra::Acts::MailChimp::SingletonMethods
          write_inheritable_attribute :email_column, opts[:email] || 'email'
          write_inheritable_attribute :type_column, opts[:type] || 'email_type'
          write_inheritable_attribute :fname_column, opts[:fname] || 'first_name'
          write_inheritable_attribute :lname_column, opts[:lname] || 'last_name'
          class_inheritable_reader    :email_column
          class_inheritable_reader    :type_column
          class_inheritable_reader    :fname_column
          class_inheritable_reader    :lname_column
        end
      end

      module SingletonMethods
        # Add class methods here
      end

      module InstanceMethods
        # Add a user to a MailChimp mailing list
        def add_to_chimp(list_name, double_opt = false)
          uid ||= mcLogin(monkeybrains[:username], monkeybrains[:password])
          list_id ||= get_list_by_name(uid, list_name)
          vars = {}
          vars.merge!({"FNAME" => self[fname_column]}) if self.has_attribute?(fname_column)
          vars.merge!({"LNAME" => self[lname_column]}) if self.has_attribute?(lname_column)
          mcSubscribe(uid, list_id["id"], self[email_column], vars, self.class.type_column, double_opt)
        rescue XMLRPC::FaultException
        end
        
        # Remove a user from a MailChimp mailing list
        def remove_from_chimp(list_name)
          uid ||= mcLogin(monkeybrains[:username], monkeybrains[:password])
          list_id ||= get_list_by_name(uid, list_name)
          mcUnsubscribe(uid, list_id["id"], self[email_column])
        rescue XMLRPC::FaultException
        end
        
        # Update user information at MailChimp
        def update_chimp(list_name, old_email = self[email_column])
          uid ||= mcLogin(monkeybrains[:username], monkeybrains[:password])
          list_id ||= get_list_by_name(uid, list_name)
          vars = {}
          vars.merge!({"FNAME" => self[fname_column]}) if self.has_attribute?(fname_column)
          vars.merge!({"LNAME" => self[lname_column]}) if self.has_attribute?(lname_column)
          vars.merge!({"EMAIL" => self[email_column]})
          mcUpdate(uid, list_id["id"], old_email, vars, self[type_column], true)
        rescue XMLRPC::FaultException
        end
        
        # Log in to MailChimp
        def mcLogin(username, password)
          raise MailChimpConfigError("Please provide a valid user and password") if (username.nil? || password.nil?) 
          mcAPI ||= XMLRPC::Client.new2("http://api.mailchimp.com/1.0/")
          mcAPI.call("login", username, password)
        end
        
        # Subscribe the provided email to a list
        def mcSubscribe(uid, list_id, email, merge_vars, content_type = 'html', double_opt = true)
          raise_errors(uid, list_id)
          mcAPI ||= XMLRPC::Client.new2("http://api.mailchimp.com/1.0/")
          mcAPI.call("listSubscribe", uid, list_id, email, merge_vars, content_type, double_opt)
        end
        
        def mcUnsubscribe(uid, list_id, email, delete_user = false, send_goodbye = true, send_notify = true)
          raise_errors(uid, list_id)
          mcAPI ||= XMLRPC::Client.new2("http://api.mailchimp.com/1.0/")
          mcAPI.call("listUnsubscribe", uid, list_id, email, delete_user, send_goodbye, send_notify)
        end
        
        def mcUpdate(uid, list_id, email, merge_vars, content_type = 'html', replace_interests = true)
          raise_errors(uid, list_id)
          mcAPI ||= XMLRPC::Client.new2("http://api.mailchimp.com/1.0/")
          mcAPI.call("listUpdateMember", uid, list_id, email, merge_vars, content_type, replace_interests)
        end
        
        def get_list_by_name(uid, list_name)
          raise MailChimpConfigError("Please provide a mailing list name") if list_name.nil?
          mailing_lists ||= get_all_lists(uid)
          unless mailing_lists.nil?  
            mailing_lists.find { |list| list["name"] == list_name }
          end
        end
        
        def get_all_lists(uid)
          raise MailChimpConnectError("Please login to MailChimp and make sure you have a valid user ID") if (uid.nil?) 
          mcAPI ||= XMLRPC::Client.new2("http://api.mailchimp.com/1.0/")
          mcAPI.call("lists", uid)
        end
        
        def raise_errors(uid, list_id)
          raise MailChimpConnectError("Please login to MailChimp and make sure you have a valid user ID") if uid.nil?
          raise MailChimpConfigError("Please provide a valid mailing list ID") if list_id.nil?
        end
        
      end
    end
  end
end
