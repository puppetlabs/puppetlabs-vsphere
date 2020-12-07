# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/puppetlabs/vsphere'

describe PuppetX::Puppetlabs::Vsphere::Machine do
  let(:machine) { described_class.new('/opdx1/vm/eng/551425a5fc66efaf') }

  it 'extracts a name from a path' do
    expect(machine.name).to eq('551425a5fc66efaf')
  end

  it 'extracts a datacenter from a path' do
    expect(machine.datacenter).to eq('opdx1')
  end

  it 'extracts a folder from a path' do
    expect(machine.folder).to eq(['eng'])
  end

  it 'extracts a local path from a path' do
    expect(machine.local_path).to eq('/eng/551425a5fc66efaf')
  end

  context 'with a deeply nested folder' do
    let(:machine) { described_class.new('/opdx1/vm/eng/test/sample/551425a5fc66efaf') }

    it 'extracts a folder from a path' do
      expect(machine.folder).to eq(['eng', 'test', 'sample'])
    end
  end
end
