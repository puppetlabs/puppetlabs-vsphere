# The Puppet Extensions Module.
module PuppetX
  # module Property.
  module Property
    # ReadOnly property
    class ReadOnly < Puppet::Property
      validate do |value|
        fail "#{self.name.to_s} is read-only and is only available via puppet resource."
      end
    end
  end
end
