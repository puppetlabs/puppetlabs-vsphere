require 'spec_helper_acceptance'
require 'securerandom'

describe 'vsphere_machine' do

  before(:all) do
    @client = VsphereHelper.new
    @template = 'machine.pp.tmpl'
  end

  describe 'should be able to create a machine' do

    before(:all) do
      @name = "CLOUD-#{SecureRandom.hex(8)}"
      @path = "/opdx1/vm/eng/test/#{@name}"
      @config = {
        :name    => @path,
        :ensure  => 'present',
        :source  => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
        :optional => {
          :memory  => 512,
          :cpus    => 2,
          :compute => 'general1',
        }
      }
      PuppetManifest.new(@template, @config).apply
      @machine = @client.get_machine(@path)
    end

    after(:all) do
      new_config = @config.update({:ensure => 'absent'})
      PuppetManifest.new(@template, new_config).apply
    end

    it 'with the specified name' do
      expect(@machine.name).to eq(@name)
    end

    it 'attached to the specified compute resource' do
      expect(@machine.resourcePool.parent.name).to eq(@config[:optional][:compute])
    end

    it 'with the specified memory setting' do
      expect(@machine.summary.config.memorySizeMB).to eq(@config[:optional][:memory])
    end

    it 'with the specified cpu setting' do
      expect(@machine.summary.config.numCpu).to eq(@config[:optional][:cpus])
    end

    it 'and should not fail to be applied multiple times' do
      success = PuppetManifest.new(@template, @config).apply[:exit_status].success?
      expect(success).to eq(true)
    end

    [:memory, :cpus].each do |read_only|
      it "when trying to set read-only property #{read_only}" do
        new_config = Marshal.load(Marshal.dump(@config))
        new_config[:optional].update({read_only => 4})
        success = PuppetManifest.new(@template, new_config).apply[:exit_status].success?
        expect(success).to eq(false)
      end
    end

    context 'when looked for using puppet resource' do
      before(:all) do
        @result = TestExecutor.puppet_resource('vsphere_machine', {:name => @path}, '--modulepath ../')
      end

      it 'should not return an error' do
        expect(@result.stderr).not_to match(/\b/)
      end

      it 'should report the correct ensure value' do
        regex = /(ensure)(\s*)(=>)(\s*)('running')/
        expect(@result.stdout).to match(regex)
      end

      it 'should report the correct memory value' do
        regex = /(memory)(\s*)(=>)(\s*)('#{@config[:optional][:memory]}')/
        expect(@result.stdout).to match(regex)
      end

      it 'should report the correct compute value' do
        regex = /(compute)(\s*)(=>)(\s*)('#{@config[:optional][:compute]}')/
        expect(@result.stdout).to match(regex)
      end

      it 'should report the correct cpu value' do
        regex = /(cpus)(\s*)(=>)(\s*)('#{@config[:optional][:cpus]}')/
        expect(@result.stdout).to match(regex)
      end

      [
        'memory_reservation',
        'cpu_reservation',
        'number_ethernet_cards',
        'power_state',
        'tools_installer_mounted',
        'snapshot_disabled',
        'snapshot_locked',
        'snapshot_power_off_behavior',
        'uuid',
        'instance_uuid',
      ].each do |read_only_property|
        it "#{read_only_property} is reported" do
          regex = /(#{read_only_property})(\s*)(=>)(\s*)/
          expect(@result.stdout).to match(regex)
        end
      end

    end

  end

  describe 'should be able to create a machine within a nested folder' do

    before(:all) do
      @name = "CLOUD-#{SecureRandom.hex(8)}"
      @path = "/opdx1/vm/eng/test/test/#{@name}"
      @config = {
        :name    => @path,
        :ensure  => 'present',
        :source  => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
        :optional => {
          :compute => 'general1',
          :memory  => 512,
          :cpus    => 1,
        }
      }
      PuppetManifest.new(@template, @config).apply
      @machine = @client.get_machine(@path)
    end

    after(:all) do
      new_config = @config.update({:ensure => 'absent'})
      PuppetManifest.new(@template, new_config).apply
    end

    it 'with the specified name' do
      expect(@machine.name).to eq(@name)
    end

  end

  describe 'should be able to create a machine from another machine' do
    before(:all) do
      @name = "CLOUD-#{SecureRandom.hex(8)}"

      @source_path = "/opdx1/vm/eng/test/#{@name}-source"
      @source_config = {
        :name    => @source_path,
        :ensure  => 'present',
        :source  => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
        :optional => {
          :compute => 'general1',
          :memory  => 512,
          :cpus    => 1,
        }
      }
      PuppetManifest.new(@template, @source_config).apply
      @source_machine = @client.get_machine(@source_path)

      @target_path = "/opdx1/vm/eng/test/#{@name}-target"
      source_vm_path = @source_path.clone
      @target_config = {
        :name   => @target_path,
        :ensure => 'present',
        :source => source_vm_path,
      }
      PuppetManifest.new(@template, @target_config).apply
      @target_machine = @client.get_machine(@target_path)
    end

    after(:all) do
      new_source_config = @source_config.update({:ensure => 'absent'})
      PuppetManifest.new(@template, new_source_config).apply

      new_target_config = @target_config.update({:ensure => 'absent'})
      PuppetManifest.new(@template, new_target_config).apply
    end

    it 'should have same config as source vm' do
      [
        :cpuReservation,
        :guestFullName,
        :guestId,
        :installBootRequired,
        :memoryReservation,
        :memorySizeMB,
        :numCpu,
        :numEthernetCards,
        :numVirtualDisks,
        :template,
      ].each do |property|
        expect(@source_machine.summary.config[property]).to eq(@target_machine.summary.config[property])
      end
    end
  end

  describe 'should be able to create a template from another template' do

    before(:all) do
      @name = "CLOUD-#{SecureRandom.hex(8)}"
      @path = "/opdx1/vm/eng/test/#{@name}"
      @config = {
        :name     => @path,
        :ensure   => 'present',
        :source   => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
        :optional => {
          :template => true,
        }
      }
      PuppetManifest.new(@template, @config).apply
      @machine = @client.get_machine(@path)
    end

    after(:all) do
      new_config = @config.update({:ensure => 'absent'})
      PuppetManifest.new(@template, new_config).apply
    end

    it 'with the specified name' do
      expect(@machine.name).to eq(@name)
    end

    it 'which is really a template' do
      expect(@machine.summary.config.template).to eq(true)
    end
  end

  describe 'should be able to create a template from another machine' do
    before(:all) do
      @name = "CLOUD-#{SecureRandom.hex(8)}"

      @source_path = "/opdx1/vm/eng/test/#{@name}-source"
      @source_config = {
        :name    => @source_path,
        :ensure  => 'present',
        :source  => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
      }
      PuppetManifest.new(@template, @source_config).apply
      @source_machine = @client.get_machine(@source_path)

      @target_path = "/opdx1/vm/eng/test/#{@name}-target"
      source_vm_path = @source_path.clone
      @target_config = {
        :name   => @target_path,
        :ensure => 'present',
        :source => source_vm_path,
        :optional => {
          :template => true,
        }
      }
      PuppetManifest.new(@template, @target_config).apply
      @target_machine = @client.get_machine(@target_path)
    end

    after(:all) do
      new_source_config = @source_config.update({:ensure => 'absent'})
      PuppetManifest.new(@template, new_source_config).apply

      new_target_config = @target_config.update({:ensure => 'absent'})
      PuppetManifest.new(@template, new_target_config).apply
    end

    it 'which is definitely a template' do
      expect(@target_machine.summary.config.template).to eq(true)
    end

    it 'should have same config as source vm' do
      [
        :cpuReservation,
        :guestFullName,
        :guestId,
        :installBootRequired,
        :memoryReservation,
        :memorySizeMB,
        :numCpu,
        :numEthernetCards,
        :numVirtualDisks,
      ].each do |property|
        expect(@source_machine.summary.config[property]).to eq(@target_machine.summary.config[property])
      end
    end
  end

end
