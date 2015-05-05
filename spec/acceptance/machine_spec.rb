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
end
