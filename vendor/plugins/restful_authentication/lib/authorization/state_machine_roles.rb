module Authorization
  module StateMachineRoles
    unless Object.constants.include? "STATE_MACHINE_ROLES_CONSTANTS_DEFINED"
      STATE_MACHINE_ROLES_CONSTANTS_DEFINED = true # sorry for the C idiom
    end
    
    def self.included( recipient )
      recipient.extend( StateMachineRolesClassMethods )
      recipient.class_eval do
        include StateMachineRolesInstanceMethods
        
        state_machine :state, :initial => 'passive' do
          
          after_transition :to => 'pending', :do => :make_activation_code
          after_transition :to => 'active',  :do => :do_activate
          after_transition :to => 'deleted', :do => :do_delete

          event :register do
            transition :from => 'passive', :to => 'pending', :if => Proc.new {|u| !(u.crypted_password.blank? && u.password.blank?) }
          end
          
          event :activate do
            transition :from => 'pending', :to => 'active'
          end
          
          event :suspend do
            transition :from => %w[passive pending active], :to => 'suspended'
          end
          
          event :delete do
            transition :from => %w[passive pending active suspended], :to => 'deleted'
          end
  
          event :unsuspend do
            transition :from => 'suspended', :to => 'active',  :if => Proc.new {|u| !u.activated_at.blank? }
            transition :from => 'suspended', :to => 'pending', :if => Proc.new {|u| !u.activation_code.blank? }
            transition :from => 'suspended', :to => 'passive'
          end
        end
      end
    end

    module StateMachineRolesClassMethods
    end # class methods

    module StateMachineRolesInstanceMethods
      # Returns true if the user has just been activated.
      def recently_activated?
        @activated
      end
      
      def do_delete
        self.deleted_at = Time.now.utc
        self.save
      end

      def do_activate
        @activated = true
        self.activated_at = Time.now.utc
        self.deleted_at = self.activation_code = nil
        self.save
      end
    end # instance methods
  end
end
