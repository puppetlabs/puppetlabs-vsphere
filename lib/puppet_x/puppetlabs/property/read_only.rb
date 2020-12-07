# frozen_string_literal: true

# The Puppet Extensions Module.
module PuppetX
  # module Property.
  module Property
    # ReadOnly property
    class ReadOnly < Puppet::Property
      validate do |_value|
        raise "#{name} is read-only and is only available via puppet resource."
      end
    end
  end
end
