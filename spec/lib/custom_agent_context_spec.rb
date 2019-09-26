require 'rails_helper'
require 'custom_agent_context'

describe CustomAgentContext do
  let (:target) { Object.new }
  subject { CustomAgentContext.new(target) }

  it 'proxies options' do
    mock(target).options { 'options' }
    expect(subject.options).to eq 'options'
  end

  it 'proxies memory reading' do
    mock(target).memory { 'memory' }
    expect(subject.memory).to eq 'memory'
  end

  it 'proxies memory writing' do
    mock(target).memory=('xyz')
    subject.memory = 'xyz'
  end

  it 'proxies logging' do
    mock(target).log('msg')
    subject.log('msg')
  end

  it 'proxies error logging' do
    mock(target).error('msg')
    subject.error('msg')
  end

  it 'creates messages' do
    mock(target).create_message(payload: 'payload')
    subject.emit_message('payload')
  end

  it 'reads credentials' do
    mock(target).credential('password') { '1234' }
    expect(subject.credential('password')).to eq '1234'
  end
end
