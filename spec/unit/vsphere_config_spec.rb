require 'spec_helper'
require 'puppet_x/puppetlabs/vsphere_config'
require 'hocon/config_factory'

def nil_environment_variables
  ENV.delete('VSPHERE_SERVER')
  ENV.delete('VSPHERE_USER')
  ENV.delete('VSPHERE_PASSWORD')
  ENV.delete('VSPHERE_DATACENTER')
  ENV.delete('VSPHERE_INSECURE')
  ENV.delete('VSPHERE_PORT')
  ENV.delete('VSPHERE_SSL')
end

def create_config_file(path, config)
  file_contents = %{
vsphere: {
  host: #{config[:host]}
  user: #{config[:user]}
  password: #{config[:password]}
  datacenter: #{config[:datacenter_name]}
}
  }
  File.open(path, 'w') { |f| f.write(file_contents) }
end

def create_full_config_file(path, config)
  file_contents = %{
vsphere: {
  host: #{config[:host]}
  user: #{config[:user]}
  password: #{config[:password]}
  datacenter: #{config[:datacenter_name]}
  insecure: #{config[:insecure]}
  port: #{config[:port]}
  ssl: #{config[:ssl]}
}
  }
  File.open(path, 'w') { |f| f.write(file_contents) }
end

def create_incomplete_config_file(path, config)
  file_contents = %{
vsphere: {
  host: #{config[:host]}
}
  }
  File.open(path, 'w') { |f| f.write(file_contents) }
end


describe PuppetX::Puppetlabs::VsphereConfig do
  let(:config_file_path) { File.join(Dir.pwd, '.puppet_vsphere.conf') }

  context 'with the relevant environment variables set' do
    let(:config) { PuppetX::Puppetlabs::VsphereConfig.new }

    before(:all) do
      @config = {
        host: 'vsphere.example.com',
        user: 'user',
        password: 'password',
        datacenter_name: 'test',
        port: '8090',
        ssl: 'false',
        insecure: 'false',
      }
      nil_environment_variables
      ENV['VSPHERE_SERVER'] = @config[:host]
      ENV['VSPHERE_USER'] = @config[:user]
      ENV['VSPHERE_PASSWORD'] = @config[:password]
      ENV['VSPHERE_DATACENTER'] = @config[:datacenter_name]
      ENV['VSPHERE_PORT'] = @config[:port]
      ENV['VSPHERE_SSL'] = @config[:ssl]
      ENV['VSPHERE_INSECURE'] = @config[:insecure]
    end

    it 'should return the host from an ENV variable' do
      expect(config.host).to eq(@config[:host])
    end

    it 'should return the user from an ENV variable' do
      expect(config.user).to eq(@config[:user])
    end

    it 'should return the password from an ENV variable' do
      expect(config.password).to eq(@config[:password])
    end

    it 'should return the datacenter from an ENV variable' do
      expect(config.datacenter).to eq(@config[:datacenter_name])
    end

    it 'should return the insecure value from an ENV variable' do
      expect(config.insecure).to eq(@config[:insecure])
    end

    it 'should return the ssl value from an ENV variable' do
      expect(config.ssl).to eq(@config[:ssl])
    end

    it 'should return the port value from an ENV variable' do
      expect(config.port).to eq(@config[:port])
    end

    it 'should set the default config file location to confdir' do
      expect(File.dirname(config.default_config_file)).to eq(Puppet[:confdir])
    end
  end

  context 'without the optional datacenter environment variables set' do
    let(:config) { PuppetX::Puppetlabs::VsphereConfig.new }

    before(:all) do
      nil_environment_variables
      ENV['VSPHERE_SERVER'] = 'vsphere.example.com'
      ENV['VSPHERE_USER'] = 'user'
      ENV['VSPHERE_PASSWORD'] = 'password'
    end

    it 'should default datacenter to nil' do
      expect(config.datacenter).to eq(nil)
    end

    it 'should default insecure to true' do
      expect(config.insecure).to eq(true)
    end

    it 'should default ssl to true' do
      expect(config.ssl).to eq(true)
    end

    it 'should default port to nil' do
      expect(config.port).to be_nil
    end
  end

  context 'with no environment variables and a valid config file with all optional properties' do
    let(:config) { PuppetX::Puppetlabs::VsphereConfig.new(config_file_path) }

    before(:all) do
      @config = {
        host: 'vsphere2.example.com',
        user: 'user2',
        password: 'password2',
        datacenter_name: 'test2',
        ssl: false,
        insecure: false,
        port: 8091,
      }
      @path = File.join(Dir.pwd, '.puppet_vsphere.conf')
      create_full_config_file(@path, @config)
      nil_environment_variables
    end

    after(:all) do
      File.delete(@path)
    end

    it 'should return the host from the config file' do
      expect(config.host).to eq(@config[:host])
    end

    it 'should return the user from the config file' do
      expect(config.user).to eq(@config[:user])
    end

    it 'should return the password from the config file' do
      expect(config.password).to eq(@config[:password])
    end

    it 'should return the datacenter from the config file' do
      expect(config.datacenter).to eq(@config[:datacenter_name])
    end

    it 'should return the insecure value from the config file' do
      expect(config.insecure).to eq(@config[:insecure])
    end

    it 'should return the ssl value from the config file' do
      expect(config.ssl).to eq(@config[:ssl])
    end

    it 'should return the port value from the config file' do
      expect(config.port).to eq(@config[:port])
    end
  end

  context 'with no environment variables and a valid config file present' do
    let(:config) { PuppetX::Puppetlabs::VsphereConfig.new(config_file_path) }

    before(:all) do
      @config = {
        host: 'vsphere2.example.com',
        user: 'user2',
        password: 'password2',
        datacenter_name: 'test2',
      }
      @path = File.join(Dir.pwd, '.puppet_vsphere.conf')
      create_config_file(@path, @config)
      nil_environment_variables
    end

    after(:all) do
      File.delete(@path)
    end

    it 'should return the host from the config file' do
      expect(config.host).to eq(@config[:host])
    end

    it 'should return the user from the config file' do
      expect(config.user).to eq(@config[:user])
    end

    it 'should return the password from the config file' do
      expect(config.password).to eq(@config[:password])
    end

    it 'should return the datacenter from the config file' do
      expect(config.datacenter).to eq(@config[:datacenter_name])
    end

    it 'should default insecure to true' do
      expect(config.insecure).to eq(true)
    end

    it 'should default ssl to true' do
      expect(config.ssl).to eq(true)
    end

    it 'should default port to nil' do
      expect(config.port).to be_nil
    end
  end

  context 'with no environment variables or config file' do
    before(:all) do
      nil_environment_variables
    end

    it 'should raise a suitable error' do
      expect {
        PuppetX::Puppetlabs::VsphereConfig.new
      }.to raise_error(Puppet::Error, /You must provide credentials in either environment variables or a config file/)
    end
  end

  context 'with incomplete configuration in environment variables' do
    before(:all) do
      ENV['VSPHERE_SERVER'] = 'vsphere.example.com'
      ENV['VSPHERE_USER'] = nil
      ENV['VSPHERE_PASSWORD'] = nil
    end

    it 'should raise an error about the missing variables' do
      expect {
        PuppetX::Puppetlabs::VsphereConfig.new
      }.to raise_error(Puppet::Error, /To use this module you must provide the following settings: user password/)
    end
  end

  context 'with no environment variables and an incomplete config file' do
    before(:all) do
      @config = {
        host: 'vsphere2.example.com',
      }
      @path = File.join(Dir.pwd, '.puppet_vsphere.conf')
      create_incomplete_config_file(@path, @config)
      nil_environment_variables
    end

    after(:all) do
      File.delete(@path)
    end

    it 'should raise an error about the missing variables' do
      expect {
        PuppetX::Puppetlabs::VsphereConfig.new(@path)
      }.to raise_error(Puppet::Error, /To use this module you must provide the following settings: user password/)
    end
  end

  context 'with no environment variables and an invalid config file' do
    before(:all) do
      @config = {
        host: 'vsphere2.example.com',
        user: nil,
      }
      @path = File.join(Dir.pwd, '.puppet_vsphere.conf')
      create_config_file(@path, @config)
      nil_environment_variables
    end

    after(:all) do
      File.delete(@path)
    end

    it 'should raise an error about the invalid config file' do
      expect {
        PuppetX::Puppetlabs::VsphereConfig.new(config_file_path)
      }.to raise_error(Puppet::Error, /Your configuration file at .+ is invalid/)
    end
  end

end
