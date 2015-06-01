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
        :name     => @path,
        :ensure   => 'present',
        :optional => {
          :source  => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
          :memory  => 512,
          :cpus    => 2,
          :compute => 'general1',
          :annotation => 'some text',
        }
      }
      PuppetManifest.new(@template, @config).apply
      @machine = @client.get_machine(@path)
    end

    after(:all) do
      @client.destroy_machine(@path)
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

    it 'with the specified annotation' do
      expect(@machine.config.annotation).to eq(@config[:optional][:annotation])
    end

    it 'and should not fail to be applied multiple times' do
      success = PuppetManifest.new(@template, @config).apply[:exit_status].success?
      expect(success).to eq(true)
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
        :name     => @path,
        :ensure   => 'present',
        :optional => {
          :source  => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
          :compute => 'general1',
          :memory  => 512,
          :cpus    => 1,
        }
      }
      PuppetManifest.new(@template, @config).apply
      @machine = @client.get_machine(@path)
    end

    after(:all) do
      @client.destroy_machine(@path)
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
        :name     => @source_path,
        :ensure   => 'present',
        :optional => {
          :source  => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
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
        :name     => @target_path,
        :ensure   => 'present',
        :optional => {
          :source => source_vm_path,
        }
      }
      PuppetManifest.new(@template, @target_config).apply
      @target_machine = @client.get_machine(@target_path)
    end

    after(:all) do
      @client.destroy_machine(@source_path)
      @client.destroy_machine(@target_path)
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
        :optional => {
          :source   => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
          :template => true,
        }
      }
      PuppetManifest.new(@template, @config).apply
      @machine = @client.get_machine(@path)
    end

    after(:all) do
      @client.destroy_machine(@path)
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
        :name     => @source_path,
        :ensure   => 'present',
        :optional => {
          :source => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
        }
      }
      PuppetManifest.new(@template, @source_config).apply
      @source_machine = @client.get_machine(@source_path)

      @target_path = "/opdx1/vm/eng/test/#{@name}-target"
      source_vm_path = @source_path.clone
      @target_config = {
        :name     => @target_path,
        :ensure   => 'present',
        :optional => {
          :source   => source_vm_path,
          :template => true,
        }
      }
      PuppetManifest.new(@template, @target_config).apply
      @target_machine = @client.get_machine(@target_path)
    end

    after(:all) do
      @client.destroy_machine(@source_path)
      @client.destroy_machine(@target_path)
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

  describe 'should be able to customize an existing machine' do
    before(:all) do
      @name = "CLOUD-#{SecureRandom.hex(8)}"

      @path = "/opdx1/vm/eng/test/#{@name}"
      @config = {
        :name     => @path,
        :ensure   => 'present',
        :optional => {
          :source  => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
          :compute => 'general1',
          :cpus    => 1,
          :memory  => 512,
          :annotation => 'some test',
        }
      }
      PuppetManifest.new(@template, @config).apply
      @config_before = @client.get_machine(@path).summary.config

      @new_config = {
        :name     => @path,
        :ensure   => 'present',
        :optional => {
          :cpus       => 2,
          :memory     => 1024,
          :annotation => 'some other test',
        }
      }
      PuppetManifest.new(@template, @new_config).apply
      @config_after = @client.get_machine(@path).summary.config
    end

    it 'should have same config for unchanged properties' do
      [
        :cpuReservation,
        :guestFullName,
        :guestId,
        :installBootRequired,
        :memoryReservation,
        :numEthernetCards,
        :numVirtualDisks,
      ].each do |property|
        expect(@config_after[property]).to eq(@config_before[property])
      end
    end

    it 'should have new config for changed properties' do
      [
        :numCpu,
        :memorySizeMB,
      ].each do |property|
        expect(@config_after[property]).not_to eq(@config_before[property])
        expect(@config_after[property].to_i).to eq(@config_before[property].to_i * 2)
      end
    end

    it 'should update the annotation' do
      expect(@config_before[:annotation]).to eq(@config[:optional][:annotation])
      expect(@config_after[:annotation]).to eq(@new_config[:optional][:annotation])
    end

    after(:all) do
      @client.destroy_machine(@path)
    end
  end

  describe 'should be able to create a linked clone from another machine' do
    before(:all) do
      @name = "CLOUD-#{SecureRandom.hex(8)}"

      @source_path = "/opdx1/vm/eng/test/#{@name}-source"
      @source_config = {
        :name     => @source_path,
        :ensure   => 'present',
        :optional => {
          :source  => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
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
        :name     => @target_path,
        :ensure   => 'present',
        :optional => {
          :source => source_vm_path,
          :linked_clone => true,
        }
      }
      PuppetManifest.new(@template, @target_config).apply
      @target_machine = @client.get_machine(@target_path)
      @disks = @target_machine.config.hardware.device.grep(RbVmomi::VIM::VirtualDisk)
    end

    after(:all) do
      @client.destroy_machine(@target_path)
      @client.destroy_machine(@source_path)
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

    it 'should have a disk attached' do
      expect(@disks).not_to be_empty
    end

    it 'should not have non linked disks' do
      own_disks = @disks.select { |x| x.backing.parent == nil }
      expect(own_disks).to be_empty
    end

    it 'should have the same disk attached as the source machine' do
      source_disks = @source_machine.config.hardware.device.grep(RbVmomi::VIM::VirtualDisk)
      expect(@disks.first.backing.parent.uuid).to eq(source_disks.first.backing.uuid)
    end

  end

end
