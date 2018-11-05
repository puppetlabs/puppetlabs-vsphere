require 'spec_helper_acceptance'
require 'securerandom'

# This set of tests requires two manually configured customization specifications on the target vCenter installation.
# They need to be called "MODULES-test-linux" and "MODULES-test-windows" respectively for the Linux and Windows
# specifications. Both need to be configured with default values, except for forcing the hostname of the machine to
# "MODULES-custom", which is what is tested by the rspecs here.

describe 'vsphere_machine' do
  def setup_machine(source, customization_spec)
    @client = VsphereHelper.new
    @name = "MODULES-#{SecureRandom.hex(8)}"
    @path = "/opdx/vm/vsphere-module-testing/eng/tests/#{@name}"
    @config = {
      :name     => @path,
      :ensure   => :present,
      :optional => {
        :source             => source,
        :source_type        => :template,
        :customization_spec => customization_spec,
      },
    }
    @template = 'machine.pp.tmpl'
    PuppetManifest.new(@template, @config).apply
  end

  [
    [ 'ubuntu-16.04-x86_64', 'MODULES-test-linux' ],
    [ 'win-2012r2-x86_64', 'MODULES-test-windows' ],
  ].each do |template, spec|
    context "when cloning #{template} using the #{spec} customization specification" do
      before(:all) do
        setup_machine("/opdx/vm/vsphere-module-testing/eng/templates/#{template}", spec)
      end

      after(:all) do
        @client.destroy_machine(@path)
      end

      it 'should create a VM with the hostname set to the value from the customization spec' do
        # The large timeout is to account for the installation time of the Windows 2012 VM
        hostname = with_retries(max_tries: 40,
                     max_sleep_seconds: 60,
                     rescue: NotFinished,
                    ) do
          machine = @client.get_machine(@path)
          hostname = machine.summary.guest.hostName
          raise NotFinished.new unless hostname == 'MODULES-custom' # Windows host has a non-empty hostname from the template
          hostname
        end
        expect(hostname).to eq('MODULES-custom')
      end
    end
  end
end
