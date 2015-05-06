require 'spec_helper_acceptance'
require 'securerandom'

describe 'vsphere_machine' do

  before(:all) do
    @client = VsphereHelper.new
    @template = 'machine.pp.tmpl'
  end

  describe 'should be able to create a machine' do

    before(:all) do
      @name = SecureRandom.hex(8)
      @path = "/opdx1/vm/eng/#{@name}"
      @config = {
        :name          => @path,
        :ensure        => 'present',
        :compute       => 'general1',
        :template_path => '/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
        :memory        => 512,
        :cpus          => 2,
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
      expect(@machine.resourcePool.parent.name).to eq(@config[:compute])
    end

    it 'with the specified memory setting' do
      expect(@machine.summary.config.memorySizeMB).to eq(@config[:memory])
    end

    it 'with the specified cpu setting' do
      expect(@machine.summary.config.numCpu).to eq(@config[:cpus])
    end

    it 'and should not fail to be applied multiple times' do
      success = PuppetManifest.new(@template, @config).apply[:exit_status].success?
      expect(success).to eq(true)
    end

    [:memory, :cpus].each do |read_only|
      it "when trying to set read-only property #{read_only}" do
        new_config = @config.dup.update({read_only => 4})
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
        regex = /(memory)(\s*)(=>)(\s*)('#{@config[:memory]}')/
        expect(@result.stdout).to match(regex)
      end

      it 'should report the correct compute value' do
        regex = /(compute)(\s*)(=>)(\s*)('#{@config[:compute]}')/
        expect(@result.stdout).to match(regex)
      end

      it 'should report the correct cpu value' do
        regex = /(cpus)(\s*)(=>)(\s*)('#{@config[:cpus]}')/
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
      ].each do |read_only_property|
        it "#{read_only_property} is reported" do
            regex = /(#{read_only_property})(\s*)(=>)(\s*)/
            expect(@result.stdout).to match(regex)
        end
      end

    end

  end

  describe 'should be able to create a machine with a nested folder' do

    before(:all) do
      @name = SecureRandom.hex(8)
      @path = "/opdx1/vm/eng/test/test/#{@name}"
      @config = {
        :name          => @path,
        :ensure        => 'present',
        :compute       => 'general1',
        :template_path => '/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
        :memory        => 512,
        :cpus          => 1,
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
      @name = SecureRandom.hex(8)

      @source_path = "/opdx1/vm/eng/test/#{@name}_source"
      @source_config = {
        :name          => @source_path,
        :ensure        => 'present',
        :compute       => 'general1',
        :template_path => '/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
        :memory        => 512,
        :cpus          => 1,
      }
      PuppetManifest.new(@template, @source_config).apply
      @source_machine = @client.get_machine(@source_path)

      @clone_template = 'clone_vm.pp.tmpl'
      @target_path = "/opdx1/vm/eng/test/clones/#{@name}_target"
      source_vm_path = @source_path.clone
      @target_config = {
        :name           => @target_path,
        :ensure         => 'present',
        :compute        => 'general1',
        :source_machine => source_vm_path,
      }
      PuppetManifest.new(@clone_template, @target_config).apply
      @target_machine = @client.get_machine(@target_path)
    end

    after(:all) do
      new_source_config = @source_config.update({:ensure => 'absent'})
      PuppetManifest.new(@template, new_source_config).apply

      new_target_config = @target_config.update({:ensure => 'absent'})
      PuppetManifest.new(@clone_template, new_target_config).apply
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
end
