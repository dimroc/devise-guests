module DeviseGuests::Controllers
  module Helpers
    extend ActiveSupport::Concern

    included do
      include ActiveSupport::Callbacks
      include ActionController::Cookies if defined?(ActionController::Cookies)
    end

    module ClassMethods
    end

    def self.define_helpers(mapping) # :nodoc:
      class_name = mapping.class_name
      mapping = mapping.name

      class_eval <<-METHODS, __FILE__, __LINE__ + 1
        def guest_#{mapping}
          return @guest_#{mapping} if @guest_#{mapping}

          if cookies.permanent[:guest_#{mapping}_id]
            @guest_#{mapping} = #{class_name}.find_by(#{class_name}.authentication_keys.first => cookies.permanent[:guest_#{mapping}_id]) rescue nil
            @guest_#{mapping} = nil if @guest_#{mapping}.respond_to? :guest and !@guest_#{mapping}.guest
          end

          @guest_#{mapping} ||= begin
            u = create_guest_#{mapping}(cookies.permanent[:guest_#{mapping}_id])
            cookies.permanent[:guest_#{mapping}_id] = u.send(#{class_name}.authentication_keys.first)
            u
          end

          @guest_#{mapping}
        end

        def current_or_guest_#{mapping}
          if current_#{mapping}
            if cookies.permanent[:guest_#{mapping}_id]
              run_callbacks :logging_in_#{mapping} do
                guest_#{mapping}.destroy unless send(:"skip_destroy_guest_#{mapping}")
                cookies.permanent[:guest_#{mapping}_id] = nil
              end
            end
            current_#{mapping}
          else
            guest_#{mapping}
          end
        end

        private
        def create_guest_#{mapping} key = nil
          auth_key = #{class_name}.authentication_keys.first
          #{class_name}.new do |g|
            g.send("\#{auth_key}=", send(:"guest_\#{auth_key}_authentication_key", key))
            g.assign_attributes(send(:"guest_#{mapping}_params"))
            g.guest = true if g.respond_to? :guest
            g.skip_confirmation! if g.respond_to?(:skip_confirmation!)
            g.save(validate: false)
          end
        end

        def guest_email_authentication_key key
          key &&= nil unless key.to_s.match(/^guest/)
          key ||= "guest_" + guest_#{mapping}_unique_suffix + "@example.com"
        end

        def guest_#{mapping}_params
          {}
        end

        def guest_#{mapping}_unique_suffix
          SecureRandom.uuid
        end

        def skip_destroy_guest_#{mapping}
          false
        end

        def transfer_guest_to_#{mapping}
        end

      METHODS

      ActiveSupport.on_load(:action_controller) do
        if respond_to?(:helper_method)
          helper_method "guest_#{mapping}", "current_or_guest_#{mapping}"
        end
        define_callbacks "logging_in_#{mapping}"
        set_callback :"logging_in_#{mapping}", :"transfer_guest_to_#{mapping}"
      end
    end
  end
end
