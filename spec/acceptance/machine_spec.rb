require 'spec_helper_acceptance'
require 'securerandom'

describe 'vsphere_vm' do

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
          :source        => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
          :source_type   => :template,
          :memory        => 512,
          :cpus          => 2,
          :resource_pool => 'general1',
          :annotation    => 'some text',
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

    it 'attached to the specified resource pool' do
      expect(@machine.resourcePool.parent.name).to eq(@config[:optional][:resource_pool])
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
        @result = TestExecutor.puppet_resource('vsphere_vm', {:name => @path}, '--modulepath ../')
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

      it 'should report the correct resource_pool value' do
        regex = /(resource_pool)(\s*)(=>)(\s*)('#{@config[:optional][:resource_pool]}')/
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
          :source        => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
          :source_type   => :template,
          :resource_pool => 'general1',
          :memory        => 512,
          :cpus          => 1,
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
          :source        => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
          :source_type   => :template,
          :resource_pool => 'general1',
          :memory        => 512,
          :cpus          => 1,
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
          :source      => source_vm_path,
          :source_type => :vm,
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
          :source      => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
          :source_type => :template,
          :template    => true,
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
          :source      => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
          :source_type => :template,
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
          :source        => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
          :source_type   => :template,
          :resource_pool => 'general1',
          :cpus          => 1,
          :memory        => 512,
          :annotation    => 'some test',
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
          :source        => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
          :source_type   => :template,
          :resource_pool => 'general1',
          :memory        => 512,
          :cpus          => 1,
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
          :source       => source_vm_path,
          :source_type  => :vm,
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

  describe 'should be able to suspend and then reset a vm' do
    before(:all) do
      @name = "CLOUD-#{SecureRandom.hex(8)}"

      @path = "/opdx1/vm/eng/test/#{@name}"
      @config = {
        :name     => @path,
        :ensure   => 'present',
        :optional => {
          :source        => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
          :source_type   => :template,
          :resource_pool => 'general1',
          :cpus          => 1,
          :memory        => 512,
        }
      }
      PuppetManifest.new(@template, @config).apply
      @state_before = @client.get_machine(@path).runtime.powerState.clone

      suspend_config = {
        :name     => @path,
        :ensure   => 'suspended',
      }
      PuppetManifest.new(@template, suspend_config).apply
      @state_suspend = @client.get_machine(@path).runtime.powerState.clone

      reset_config = {
        :name     => @path,
        :ensure   => 'reset',
      }
      PuppetManifest.new(@template, reset_config).apply
      @state_reset = @client.get_machine(@path).runtime.powerState.clone
    end

    it 'should change state correctly' do
      expect(@state_before).to eq('poweredOn')
      expect(@state_suspend).to eq('suspended')
      expect(@state_reset).to eq('poweredOn')
    end

    after(:all) do
      @client.destroy_machine(@path)
    end
  end

  describe 'should be able to create a machine and run a command on the guest' do

    before(:all) do
      @name = "CLOUD-#{SecureRandom.hex(8)}"
      @path = "/opdx1/vm/eng/test/#{@name}"
      template = 'machine_create_command.pp.tmpl'
      @config = {
        :name     => @path,
        :ensure   => 'present',
        :optional => {
          :source      => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
          :source_type => :template,
        },
        :create_command => {
          :command => '/bin/ps',
          :arguments => 'aux',
          :user => ENV['VSPHERE_GUEST_USERNAME'],
          :password => ENV['VSPHERE_GUEST_PASSWORD'],
        }
      }
      PuppetManifest.new(template, @config).apply
      @machine = @client.get_machine(@path)
      @processes = @client.list_processes(@path)
    end

    after(:all) do
      @client.destroy_machine(@path)
    end

    it 'with the specified name' do
      expect(@machine.name).to eq(@name)
    end

    it 'with processes running on the guest' do
      expect(@processes).not_to be_empty
    end

    it 'with the named process running on the guest' do
      expect(@processes.first.name).to eq('ps')
    end

    it 'with the named process running the relevant command' do
      expect(@processes.first.cmdLine).to eq('"/bin/ps" aux')
    end

    it 'with the named process owned by the correct user' do
      expect(@processes.first.owner).to eq(ENV['VSPHERE_GUEST_USERNAME'])
    end
  end

  describe 'should create a machine but fail to run command on the guest' do

    context 'with invalid guest credentials' do

      before(:all) do
        name = "CLOUD-#{SecureRandom.hex(8)}"
        @path = "/opdx1/vm/eng/test/#{name}"
        @template = 'machine_create_command.pp.tmpl'
        @config = {
          :name     => @path,
          :ensure   => 'present',
          :optional => {
            :source      => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
            :source_type => :template,
          },
          :create_command => {
            :command => '/bin/ps',
            :arguments => 'aux',
            :user => 'invalid',
            :password => 'invalid',
          }
        }
        @apply = PuppetManifest.new(@template, @config).apply
      end

      after(:all) do
        @client.destroy_machine(@path)
      end

      it 'should create a machine' do
        expect(@client.get_machine(@path)).not_to be_nil
      end

      it 'should fail to apply successfully' do
        success = @apply[:exit_status].success?
        expect(success).to eq(false)
      end

      it 'should report the incorrect credentials' do
        expect(@apply[:output].map { |i| i.include? 'Incorrect credentials for the guest machine' }.include? true).to eq(true)
      end
    end
  end

  describe 'should provide useful error messages' do

    context 'for a machine with an invalid source machine' do

      before(:all) do
        name = "CLOUD-#{SecureRandom.hex(8)}"
        @path = "/opdx1/vm/eng/test/#{name}"
        @config = {
          :name     => @path,
          :ensure   => 'present',
          :optional => {
            :source  => '/opdx1/vm/eng/templates/invalid',
          },
        }
        @apply = PuppetManifest.new(@template, @config).apply
      end

      it 'should not create a machine' do
        expect(@client.get_machine(@path)).to be_nil
      end

      it 'should fail to apply successfully' do
        success = @apply[:exit_status].success?
        expect(success).to eq(false)
      end

      it 'should report the problem' do
        expect(@apply[:output].map { |i| i.include? 'No machine found at /eng/templates/invalid' }.include? true).to eq(true)
      end
    end

    context 'for an non-existent machine with no source property' do

      before(:all) do
        name = "CLOUD-#{SecureRandom.hex(8)}"
        @path = "/opdx1/vm/eng/test/#{name}"
        @config = {
          :name     => @path,
          :ensure   => 'present',
        }
        @apply = PuppetManifest.new(@template, @config).apply
      end

      it 'should not create a machine' do
        expect(@client.get_machine(@path)).to be_nil
      end

      it 'should fail to apply successfully' do
        success = @apply[:exit_status].success?
        expect(success).to eq(false)
      end

      it 'should report the problem' do
        expect(@apply[:output].map { |i| i.include? 'Must provide a source machine or template to base the new machine on' }.include? true).to eq(true)
      end
    end

    context 'for a machine with an invalid resource pool' do

      before(:all) do
        name = "CLOUD-#{SecureRandom.hex(8)}"
        @path = "/opdx1/vm/eng/test/#{name}"
        @config = {
          :name     => @path,
          :ensure   => 'present',
          :optional => {
            :resource_pool => 'invalid',
            :source        => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
          },
        }
        @apply = PuppetManifest.new(@template, @config).apply
      end

      it 'should not create a machine' do
        expect(@client.get_machine(@path)).to be_nil
      end

      it 'should fail to apply successfully' do
        success = @apply[:exit_status].success?
        expect(success).to eq(false)
      end

      it 'should report the problem' do
        expect(@apply[:output].map { |i| i.include? "No resource pool found named #{@config[:optional][:resource_pool]}" }.include? true).to eq(true)
      end
    end

    context 'for a machine specifying a read-only property' do

      before(:all) do
        name = "CLOUD-#{SecureRandom.hex(8)}"
        @path = "/opdx1/vm/eng/test/#{name}"
        @config = {
          :name     => @path,
          :ensure   => 'present',
          :optional => {
            :uuid   => 'invalid',
            :source => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
          },
        }
        @apply = PuppetManifest.new(@template, @config).apply
      end

      it 'should not create a machine' do
        expect(@client.get_machine(@path)).to be_nil
      end

      it 'should fail to apply successfully' do
        success = @apply[:exit_status].success?
        expect(success).to eq(false)
      end

      it 'should report the problem' do
        expect(@apply[:output].map { |i| i.include? "uuid is read-only and is only available via puppet resource." }.include? true).to eq(true)
      end
    end

    context 'for a template with an invalid source machine' do

      before(:all) do
        name = "CLOUD-#{SecureRandom.hex(8)}"
        @path = "/opdx1/vm/eng/test/#{name}"
        @config = {
          :name     => @path,
          :ensure   => 'present',
          :optional => {
            :source   => '/opdx1/vm/eng/templates/invalid',
            :template => true,
          },
        }
        @apply = PuppetManifest.new(@template, @config).apply
      end

      it 'should not create a template' do
        expect(@client.get_machine(@path)).to be_nil
      end

      it 'should fail to apply successfully' do
        success = @apply[:exit_status].success?
        expect(success).to eq(false)
      end

      it 'should report the problem' do
        expect(@apply[:output].map { |i| i.include? 'No machine found at /eng/templates/invalid' }.include? true).to eq(true)
      end
    end
  end

  describe 'should be able to register a vm on disk' do
    before(:all) do
      @name = "CLOUD-#{SecureRandom.hex(8)}"

      @path = "/opdx1/vm/eng/test/#{@name}"
      @config = {
        :name     => @path,
        :ensure   => 'present',
        :optional => {
          :source  => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
          :source_type   => :template,
          :resource_pool => 'general1',
          :cpus          => 1,
          :memory        => 512,
        }
      }
      PuppetManifest.new(@template, @config).apply
      machine = @client.get_machine(@path)
      @original_config = machine.summary.config

      unregister_config = {
        :name     => @path,
        :ensure   => 'absent',
        :optional => {
          :delete_from_disk => false,
        },
      }
      PuppetManifest.new(@template, unregister_config).apply
      @unregistered_machine = @client.get_machine(@path)

      register_config = {
        :name     => @path,
        :ensure   => 'present',
        :optional => {
          :source      => @name,
          :source_type => 'folder',
        },
      }
      PuppetManifest.new(@template, register_config).apply
      @newly_register_machine = @client.get_machine(@path)
    end

    it 'should successfully unregister the original vm' do
      expect(@unregistered_machine).to be_nil
    end

    it 'should successfully register the vm from disk' do
      expect(@newly_register_machine).not_to be_nil
    end

    it 'should have same config as original vm' do
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
        expect(@newly_register_machine.summary.config[property]).to eq(@original_config[property])
      end
    end

    after(:all) do
      @client.destroy_machine(@path)
    end
  end
end
