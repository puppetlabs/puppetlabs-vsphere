# frozen_string_literal: true

require 'spec_helper'

type_class = Puppet::Type.type(:vsphere_vm)

describe type_class do
  let :params do
    [
      :name,
      :source,
      :source_type,
      :customization_spec,
      :linked_clone,
      :create_command,
      :delete_from_disk,
      :datastore,
    ]
  end

  let :properties do
    [
      :ensure,
      :memory,
      :cpus,
      :resource_pool,
      :template,
      :extra_config,
      :annotation,
    ]
  end

  let :read_only_properties do
    [
      :cpu_reservation,
      :datacenter,
      :guest_ip,
      :hostname,
      :instance_uuid,
      :memory_reservation,
      :number_ethernet_cards,
      :power_state,
      :snapshot_disabled,
      :snapshot_locked,
      :snapshot_power_off_behavior,
      :tools_installer_mounted,
      :uuid,
      :drs_behavior,
      :memory_affinity,
      :cpu_affinity,
    ]
  end

  it 'has expected properties' do
    all_properties = properties + read_only_properties
    all_properties.each do |property|
      expect(type_class.properties.map(&:name)).to be_include(property)
    end
  end

  it 'has expected parameters' do
    params.each do |param|
      expect(type_class.parameters).to be_include(param)
    end
  end

  it 'requires a name' do
    expect {
      type_class.new({})
    }.to raise_error(Puppet::Error, 'Title or name must be provided')
  end

  it 'requires the last part of the name to be no more than 80 characters' do
    expect {
      type_class.new(name: '/dc/vm/a-far-too-long-name-with-lots-of-words-in-it-that-apparently-goes-on-for-ever-and-a-day-oh-please-make-it-stop')
    }.to raise_error(Puppet::Error, %r{should be no more than 80 characters})
  end

  [
    'name',
    'resource_pool',
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
    'create_command',
  ].each do |param|
    it "should require #{param}' to be a hash" do
      expect(type_class).to require_hash_for(param)
    end
  end

  it 'requires memory to be greater than 0' do
    expect {
      type_class.new(name: 'sample', memory: 0)
    }.to raise_error(Puppet::Error, %r{memory should be greater than 0})
  end

  it 'requires number of cpus to be greater than 0' do
    expect {
      type_class.new(name: 'sample', cpus: 0)
    }.to raise_error(Puppet::Error, %r{cpus should be greater than 0})
  end

  it 'supports :running as a value to :ensure' do
    type_class.new(name: 'sample', ensure: :running)
  end

  it 'supports :stopped as a value to :ensure' do
    type_class.new(name: 'sample', ensure: :stopped)
  end

  it 'defaults template to false' do
    machine = type_class.new(name: 'sample')
    expect(machine[:template]).to eq(:false)
  end

  it 'defaults source_type to vm' do
    machine = type_class.new(name: 'sample')
    expect(machine[:source_type]).to eq(:vm)
  end

  it 'defaults delete_from_disk to true' do
    machine = type_class.new(name: 'sample')
    expect(machine[:delete_from_disk]).to eq(:true)
  end

  it 'defaults linked_clone to false' do
    machine = type_class.new(name: 'sample')
    expect(machine[:linked_clone]).to eq(:false)
  end

  it 'defaults ensure to present' do
    machine = type_class.new(name: 'sample')
    expect(machine[:ensure]).to eq(:present)
  end

  it 'supports true as a value to template' do
    expect { type_class.new(name: 'sample', template: true) }.not_to raise_error
  end

  it 'supports false as a value to template' do
    expect { type_class.new(name: 'sample', template: false) }.not_to raise_error
  end

  it 'requires template to be a boolean' do
    expect { type_class.new(name: 'sample', template: 'sample') }.to raise_error
  end

  it 'supports vm as a value to source_type' do
    expect { type_class.new(name: 'sample', source_type: 'vm') }.not_to raise_error
  end

  it 'supports template as a value to source_type' do
    expect { type_class.new(name: 'sample', source_type: 'template') }.not_to raise_error
  end

  it 'supports folder as a value to source_type' do
    expect { type_class.new(name: 'sample', source_type: 'folder') }.not_to raise_error
  end

  it 'requires vm, template, or folder as a value to source_type' do
    expect { type_class.new(name: 'sample', source_type: 'magic') }.to raise_error
  end

  it 'supports true as a value to delete_from_disk' do
    expect { type_class.new(name: 'sample', delete_from_disk: true) }.not_to raise_error
  end

  it 'supports false as a value to delete_from_disk' do
    expect { type_class.new(name: 'sample', delete_from_disk: false) }.not_to raise_error
  end

  it 'requires delete_from_disk to be a boolean' do
    expect { type_class.new(name: 'sample', delete_from_disk: 'sample') }.to raise_error
  end

  it 'supports true as a value to linked_clone' do
    expect { type_class.new(name: 'sample', linked_clone: true) }.not_to raise_error
  end

  it 'supports false as a value to linked_clone' do
    expect { type_class.new(name: 'sample', linked_clone: false) }.not_to raise_error
  end

  it 'requires linked_clone to be a boolean' do
    expect { type_class.new(name: 'sample', linked_clone: 'sample') }.to raise_error
  end

  it 'requires datastore to be a string' do
    expect { type_class.new(name: 'sample', datastore: true) }.to raise_error
  end

  [
    :cpu_reservation,
    :datacenter,
    :guest_ip,
    :guest_os,
    :hostname,
    :instance_uuid,
    :memory_reservation,
    :number_ethernet_cards,
    :power_state,
    :snapshot_disabled,
    :snapshot_locked,
    :snapshot_power_off_behavior,
    :tools_installer_mounted,
    :uuid,
    :drs_behavior,
    :memory_affinity,
    :cpu_affinity,
  ].each do |property|
    it "should require #{property} to be read only" do
      expect(type_class).to be_read_only(property)
    end
  end

  it 'acknowledges stopped instance to be present' do
    machine = type_class.new(name: 'sample', ensure: :present)
    expect(machine.property(:ensure).insync?(:stopped)).to be true
  end

  context 'with a full set of properties' do
    before :all do
      @machine = type_class.new(ensure: :present,
                                name: 'garethr-test',
                                resource_pool: 'general',
                                memory: '1024',
                                cpus: '1',
                                source: '/dc/org/templates/template')
    end

    it 'permits strings for memory' do
      expect(@machine.property(:memory).insync?('1024')).to be true
    end

    it 'permits integers for memory' do
      expect(@machine.property(:memory).insync?(1024)).to be true
    end

    it 'permits integers for cpus' do
      expect(@machine.property(:cpus).insync?(1)).to be true
    end

    it 'permits strings for cpus' do
      expect(@machine.property(:cpus).insync?('1')).to be true
    end

    it 'aliases running to present for ensure values' do
      expect(@machine.property(:ensure).insync?(:running)).to be true
    end

    context 'when out of sync' do
      it 'reports actual state if desired state is present, as present is overloaded' do
        expect(@machine.property(:ensure).change_to_s(:running, :present)).to eq(:running)
      end

      it 'if current and desired are the same then should report value' do
        expect(@machine.property(:ensure).change_to_s(:stopped, :stopped)).to eq(:stopped)
      end

      it 'if current and desired are different should report change' do
        expect(@machine.property(:ensure).change_to_s(:stopped, :running)).to eq('changed stopped to running')
      end
    end
  end

  it 'prohibits specifying resource pool for templates' do
    expect {
      type_class.new(name: 'sample', resource_pool: 'something', template: true)
    }.to raise_error(RuntimeError, %r{Cannot provide the following properties for a template: resource_pool})
  end

  it 'prohibits specifying cpu for templates' do
    expect {
      type_class.new(name: 'sample', cpus: 2, template: true)
    }.to raise_error(RuntimeError, %r{Cannot provide the following properties for a template: cpus})
  end

  it 'prohibits specifying memory for templates' do
    expect {
      type_class.new(name: 'sample', memory: 512, template: true)
    }.to raise_error(RuntimeError, %r{Cannot provide the following properties for a template: memory})
  end

  it 'reports mutiple invalid properties for templates' do
    expect {
      type_class.new(name: 'sample', memory: 512, cpus: 2, template: true)
    }.to raise_error(RuntimeError, %r{Cannot provide the following properties for a template: cpus, memory})
  end

  ['running', 'stopped'].each do |state|
    it "should prohibit specifying ensure as #{state} for templates" do
      expect {
        type_class.new(name: 'sample', ensure: state, template: true)
      }.to raise_error(RuntimeError, %r{Templates can only be absent or present.})
    end
  end

  context 'with a create_command specified' do
    before :all do
      @config = {
        ensure: :present,
        name: 'garethr-test',
        source: '/dc/org/templates/template',
        create_command: {
          command: '/bin/ps',
          user: 'root',
          password: 'password',
        },
      }
    end

    ['command', 'user', 'password'].each do |key|
      it "should require create_command to have a #{key} key" do
        expect {
          config = Marshal.load(Marshal.dump(@config))
          config[:create_command].delete(key.to_sym)
          type_class.new(config)
        }.to raise_error(Puppet::Error, %r{for create_command you are missing the following keys: #{key}})
      end
    end
  end
end
