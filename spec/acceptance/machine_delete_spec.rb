require 'spec_helper_acceptance'
require 'securerandom'

shared_context 'a running vm' do
  before(:all) do
    @client = VsphereHelper.new
    @template = 'machine.pp.tmpl'
    @name = "MODULES-#{SecureRandom.hex(8)}"
    @path = "/opdx/vm/vsphere-module-testing/#{@name}"
    @config = {
      :name     => @path,
      :optional => {
        :source      => '/opdx/vm/vsphere-module-testing/eng/templates/debian-8-x86_64',
        :source_type => :template,
      },
    }
    datacenter = @client.datacenter
    path = @config[:optional][:source]
    path.slice!('/opdx/vm')
    template = datacenter.find_vm(path)
    pool = datacenter.hostFolder.children.first.resourcePool
    relocate_spec = RbVmomi::VIM.VirtualMachineRelocateSpec(:pool => pool)
    clone_spec = RbVmomi::VIM.VirtualMachineCloneSpec(
      :location => relocate_spec,
      :powerOn  => true,
      :template => false)
    clone_spec.config = RbVmomi::VIM.VirtualMachineConfigSpec(deviceChange: [])
    target_folder = datacenter.vmFolder.find('vsphere-module-testing')
    template.CloneVM_Task(
      :folder => target_folder,
      :name   => @name,
      :spec   => clone_spec).wait_for_completion

    @datastore = @client.datacenter.datastore.first
    @machine = @client.get_machine(@path)
  end

  after(:all) do
    @client.destroy_machine(@path)
  end
end

describe 'vsphere_vm' do
  describe 'should be able to unregister a machine' do
    include_context 'a running vm'

    before(:all) do
      @unregister_config = {
        :name     => @path,
        :ensure   => :absent,
        :optional => {
          :delete_from_disk => false,
        },
      }
      PuppetManifest.new(@template, @unregister_config).apply
    end

    it 'should be removed' do
      machine = @client.get_machine(@path)
      expect(machine).to be_nil
    end

    it 'should not fail to be applied multiple times' do
      success = PuppetManifest.new(@template, @unregister_config).apply[:exit_status].success?
      expect(success).to eq(true)
    end

    it 'should keep the machine\'s vmx file around' do
      vmx = @datastore.browser.SearchDatastoreSubFolders_Task({:datastorePath => "[#{@datastore.name}] #{@name}", :searchSpec => { :matchPattern => ["#{@name}.vmx"] } }).wait_for_completion
      expect(vmx).not_to be_nil
      expect(vmx.first.file.first.path).to eq("#{@name}.vmx")
    end

    it 'should keep the machine\'s vmdk file around' do
      vmdk = @datastore.browser.SearchDatastoreSubFolders_Task({:datastorePath => "[#{@datastore.name}] #{@name}", :searchSpec => { :matchPattern => ["#{@name}_19.vmdk"] } }).wait_for_completion
      expect(vmdk).not_to be_nil
      expect(vmdk.first.file.first.path).to eq("#{@name}_19.vmdk")
    end

    context 'when looked for using puppet resource' do
      before(:all) do
        @result = TestExecutor.puppet_resource('vsphere_vm', {:name => @path})
      end

      it 'should not return an error' do
        expect(@result.stderr).not_to match(/\b/)
      end

      it 'should report the correct ensure value' do
        regex = /(ensure)(\s*)(=>)(\s*)('absent')/
        expect(@result.stdout).to match(regex)
      end

    end

  end

  describe 'should be able to delete a machine' do
    include_context 'a running vm'

    before(:all) do
      @absent_config = {
        :name     => @path,
        :ensure   => :absent,
        :optional => {
          :delete_from_disk => true,
        },
      }
      PuppetManifest.new(@template, @absent_config).apply
    end

    it 'should be removed' do
      @machine = @client.get_machine(@path)
      expect(@machine).to be_nil
    end

    it 'and should not fail to be applied multiple times' do
      success = PuppetManifest.new(@template, @absent_config).apply[:exit_status].success?
      expect(success).to eq(true)
    end

    it 'should have removed the machine\'s vmx file' do
      expect {
        @datastore.browser.SearchDatastoreSubFolders_Task({:datastorePath => "[#{@datastore.name}] #{@name}", :searchSpec => { :matchPattern => ["#{@name}.vmx"] } }).wait_for_completion
      }.to raise_error(RbVmomi::Fault, /FileNotFound/)
    end

    it 'should have removed the machine\'s vmdk file' do
      expect {
        @datastore.browser.SearchDatastoreSubFolders_Task({:datastorePath => "[#{@datastore.name}] #{@name}", :searchSpec => { :matchPattern => ["#{@name}_19.vmdk"] } }).wait_for_completion
      }.to raise_error(RbVmomi::Fault, /FileNotFound/)
    end

    context 'when looked for using puppet resource' do
      before(:all) do
        @result = TestExecutor.puppet_resource('vsphere_vm', {:name => @path})
      end

      it 'should not return an error' do
        expect(@result.stderr).not_to match(/\b/)
      end

      it 'should report the correct ensure value' do
        regex = /(ensure)(\s*)(=>)(\s*)('absent')/
        expect(@result.stdout).to match(regex)
      end
    end

  end
end
