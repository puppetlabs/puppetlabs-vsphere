require 'spec_helper'
require 'puppet_x/puppetlabs/vsphere'

describe PuppetX::Puppetlabs::Vsphere::Machine do
  let(:machine) { PuppetX::Puppetlabs::Vsphere::Machine.new('/opdx1/vm/eng/551425a5fc66efaf') }

  it 'should extract a name from a path' do
    expect(machine.name).to eq('551425a5fc66efaf')
  end

  it 'should extract a datacenter from a path' do
    expect(machine.datacenter).to eq('opdx1')
  end

  it 'should extract a folder from a path' do
    expect(machine.folder).to eq(['eng'])
  end

  it 'should extract a local path from a path' do
    expect(machine.local_path).to eq('/eng/551425a5fc66efaf')
  end

  context 'with a deeply nested folder' do
    let(:machine) { PuppetX::Puppetlabs::Vsphere::Machine.new('/opdx1/vm/eng/test/sample/551425a5fc66efaf') }
    it 'should extract a folder from a path' do
      expect(machine.folder).to eq(['eng', 'test', 'sample'])
    end
  end

end
