require 'spec_helper_acceptance'
require 'securerandom'

describe 'vsphere_machine' do

  before(:all) do
    @client = VsphereHelper.new
    @template = 'machine.pp.tmpl'
  end

  def get_machine(name)
    machines = @client.get_machines(name)
    expect(machines.count).to eq(1)
    machines.first
  end

  describe 'should be able to create a machine' do

    before(:all) do
      @name = SecureRandom.hex(8)
      @config = {
        :name => @name,
        :ensure => 'present',
        :memory => 1024,
        :cpus => 1,
        :folder => 'eng',
        :vdc => 'opdx1',
        :template_path => '/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
      }
      PuppetManifest.new(@template, @config).apply
      @machine = get_machine(@name)
    end

    after(:all) do
      new_config = @config.update({:ensure => 'absent'})
      PuppetManifest.new(@template, new_config).apply
    end

    it 'with the specified name' do
      expect(@machine.name).to eq(@name)
    end

    context 'when looked for using puppet resource' do
      before(:all) do
        @result = TestExecutor.puppet_resource('vsphere_machine', {:name => @name}, '--modulepath ../')
      end

      it 'should not return an error' do
        expect(@result.stderr).not_to match(/\b/)
      end

      it 'should report the correct ensure value' do
        regex = /(ensure)(\s*)(=>)(\s*)('present')/
        expect(@result.stdout).to match(regex)
      end
    end

  end

end
