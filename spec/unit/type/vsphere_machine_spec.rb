require 'spec_helper'

type_class = Puppet::Type.type(:vsphere_machine)

describe type_class do

  let :params do
    [
      :name,
      :template,
      :source_machine,
    ]
  end

  let :properties do
    [
      :ensure,
      :memory,
      :cpus,
      :compute,
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
    'template',
    'compute',
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

  [
    :memory_reservation,
    :cpu_reservation,
    :number_ethernet_cards,
    :power_state,
    :tools_installer_mounted,
    :snapshot_disabled,
    :snapshot_locked,
    :snapshot_power_off_behavior,
  ].each do |property|
    it "should require #{property} to be read only" do
      expect(type_class).to be_read_only(property)
    end
  end

  context 'with a full set of properties' do
    before :all do
      @machine = type_class.new({
        ensure: :present,
        name: 'garethr-test',
        compute: 'general',
        memory: '1024',
        cpus: '1',
        template: '/dc/org/templates/template',
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

    it 'should alias running to present for ensure values ' do
      expect(@machine.property(:ensure).insync?(:running)).to be true
    end

  end

  it 'should prohibit source_machine and template to be set together' do
    expect {
      type_class.new({name: 'sample', source_machine: 'something', template: 'something'})
    }.to raise_error(Puppet::Error, /Cannot specify both template and source_machine/)
  end

end
