require 'spec_helper_acceptance'
require 'securerandom'

# This set of tests requires two manually configured customization specifications on the target vCenter installation.
# They need to be called "CLOUD-test-linux" and "CLOUD-test-windows" respectively for the Linux and Windows
# specifications. Both need to be configured with default values, except for forcing the hostname of the machine to
# "CLOUD-custom", which is what is tested by the rspecs here.

describe 'vsphere_machine' do
  def setup_machine(source, customization_spec)
    @client = VsphereHelper.new
    @name = "CLOUD-#{SecureRandom.hex(8)}"
    @path = "/opdx1/vm/eng/test/#{@name}"
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
    @machine = @client.get_machine(@path)
  end

  [
    [ 'centos-6-x86_64', 'CLOUD-test-linux' ],
    [ 'win-2012r2-x86_64', 'CLOUD-test-windows' ],
  ].each do |template, spec|
    context "when cloning #{template} using the #{spec} customization specification" do
      before(:all) do
        setup_machine("/opdx1/vm/eng/templates/#{template}", spec)
      end

      after(:all) do
        @client.destroy_machine(@path)
      end

      it 'should create a VM with the hostname set to the value from the customization spec' do
        hostname = with_retries(max_tries: 20,
                     max_sleep_seconds: 60,
                     rescue: NotFinished,
                    ) do
          hostname = @machine.summary.guest.hostName
          raise NotFinished.new unless hostname == 'CLOUD-custom' # Windows host has a non-empty hostname from the template
          hostname
        end
        expect(hostname).to eq('CLOUD-custom')
      end
    end
  end
end
