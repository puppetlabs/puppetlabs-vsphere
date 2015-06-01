require 'spec_helper'

type_class = Puppet::Type.type(:vsphere_machine)

describe type_class do

  let :params do
    [
      :name,
      :source,
    ]
  end

  let :properties do
    [
      :ensure,
      :memory,
      :cpus,
      :compute,
      :template,
      :extra_config,
      :annotation,
    ]
  end

  let :read_only_properties do
    [
      :memory_reservation,
      :cpu_reservation,
      :number_ethernet_cards,
      :power_state,
      :tools_installer_mounted,
      :snapshot_disabled,
      :snapshot_locked,
      :snapshot_power_off_behavior,
      :uuid,
      :instance_uuid,
      :guest_ip,
      :hostname,
    ]
  end

  it 'should have expected properties' do
    all_properties = properties + read_only_properties
    all_properties.each do |property|
      expect(type_class.properties.map(&:name)).to be_include(property)
    end
  end

  it 'should have expected parameters' do
    params.each do |param|
      expect(type_class.parameters).to be_include(param)
    end
  end

  it 'should require a name' do
    expect {
      type_class.new({})
    }.to raise_error(Puppet::Error, 'Title or name must be provided')
  end

  [
    'name',
    'compute',
    'annotation',
  ].each do |property|
    it "should require #{property} to be a string" do
      expect(type_class).to require_string_for(property)
    end
  end

  [
    'cpus',
    'memory',
  ].each do |property|
    it "should require #{property} to be a number" do
      expect(type_class).to require_integer_for(property)
    end
  end

  [
    'extra_config',
  ].each do |param|
    it "should require #{param}' to be a hash" do
      expect(type_class).to require_hash_for(param)
    end
  end

  it 'should require CPUs to be greater than 0' do
    expect {
      type_class.new({})
    }.to raise_error(Puppet::Error, 'Title or name must be provided')
  end

  it 'should require memory to be greater than 0' do
    expect {
      type_class.new({name: 'sample', memory: 0})
    }.to raise_error(Puppet::Error, /memory should be greater than 0/)
  end

  it 'should require number of cpus to be greater than 0' do
    expect {
      type_class.new({name: 'sample', cpus: 0})
    }.to raise_error(Puppet::Error, /cpus should be greater than 0/)
  end

  it 'should support :running as a value to :ensure' do
    type_class.new(:name => 'sample', :ensure => :running)
  end

  it 'should support :stopped as a value to :ensure' do
    type_class.new(:name => 'sample', :ensure => :running)
  end

  it 'should support :unregistered as a value to :ensure' do
    type_class.new(:name => 'sample', :ensure => :unregistered)
  end

  it 'should default template to false' do
    machine = type_class.new(:name => 'sample')
    expect(machine[:template]).to eq(:false)
  end

  it 'should default ensure to present' do
    machine = type_class.new(:name => 'sample')
    expect(machine[:ensure]).to eq(:present)
  end

  it 'should support true as a value to template' do
    expect{type_class.new(:name => 'sample', :template => true)}.to_not raise_error
  end

  it 'should support false as a value to template' do
    expect{type_class.new(:name => 'sample', :template => false)}.to_not raise_error
  end

  it 'should require template to be a boolean' do
    expect{type_class.new(:name => 'sample', :template => 'sample')}.to raise_error
  end

  [
    :memory_reservation,
    :cpu_reservation,
    :number_ethernet_cards,
    :power_state,
    :tools_installer_mounted,
    :snapshot_disabled,
    :snapshot_locked,
    :snapshot_power_off_behavior,
    :uuid,
    :instance_uuid,
    :guest_ip,
    :hostname,
  ].each do |property|
    it "should require #{property} to be read only" do
      expect(type_class).to be_read_only(property)
    end
  end

  it 'should acknowledge stopped instance to be present' do
    machine = type_class.new(:name => 'sample', :ensure => :present)
    expect(machine.property(:ensure).insync?(:stopped)).to be true
  end

  it 'should acknowledge unregistered instance to be absent' do
    machine = type_class.new(:name => 'sample', :ensure => :unregistered)
    expect(machine.property(:ensure).insync?(:absent)).to be true
  end

  context 'with a full set of properties' do
    before :all do
      @machine = type_class.new({
        ensure: :present,
        name: 'garethr-test',
        compute: 'general',
        memory: '1024',
        cpus: '1',
        source: '/dc/org/templates/template',
      })
    end

    it 'should permit strings for memory' do
      expect(@machine.property(:memory).insync?('1024')).to be true
    end

    it 'should permit integers for memory' do
      expect(@machine.property(:memory).insync?(1024)).to be true
    end

    it 'should permit integers for cpus' do
      expect(@machine.property(:cpus).insync?(1)).to be true
    end

    it 'should permit strings for cpus' do
      expect(@machine.property(:cpus).insync?('1')).to be true
    end

    it 'should alias running to present for ensure values' do
      expect(@machine.property(:ensure).insync?(:running)).to be true
    end

  end

  it 'should prohibit specifying compute for templates' do
    expect {
      type_class.new({name: 'sample', compute: 'something', template: true})
    }.to raise_error(Puppet::Error, /Cannot provide compute for a template/)
  end

  ['running', 'stopped'].each do |state|
    it "should prohibit specifying ensure as #{state} for templates" do
      expect {
        type_class.new({name: 'sample', ensure: state, template: true})
      }.to raise_error(Puppet::Error, /Templates can only be absent, present or unregistered./)
    end
  end

end
