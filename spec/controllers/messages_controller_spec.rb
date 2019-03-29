require 'rails_helper'

describe MessagesController do
  before do
    expect(Message.where(user_id: users(:bob).id).count).to be > 0
    expect(Message.where(user_id: users(:jane).id).count).to be > 0
  end

  describe 'GET index' do
    it 'only returns Messages created by this Agent' do
      sign_in users(:bob)
      get :index, params: { agent_id: agents(:bob_website_agent) }
      expect(assigns(:messages).length).to eq(agents(:bob_website_agent).messages.length)
      expect(assigns(:messages).all? { |i| expect(i.agent).to eq(agents(:bob_website_agent)) }).to be_truthy
    end

    it 'only returns messages of the current user' do
      sign_in users(:bob)
      get :index, params: { agent_id: agents(:bob_website_agent) }
      expect(assigns(:messages).length).to eq(agents(:bob_website_agent).messages.length)
      expect(assigns(:messages).all? { |i| expect(i.agent).to eq(agents(:bob_website_agent)) }).to be_truthy

      expect {
        get :index, params: { agent_id: agents(:jane_website_agent) }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'GET show' do
    it 'only shows Messages for the current user' do
      sign_in users(:bob)
      get :show, params: { id: messages(:bob_website_agent_message).to_param,
                           agent_id: agents(:bob_website_agent) }
      expect(assigns(:message)).to eq(messages(:bob_website_agent_message))

      expect {
        get :show, params: { id: messages(:jane_website_agent_message).to_param,
                             agent_id: agents(:jane_website_agent) }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'POST reemit' do
    before do
      sign_in users(:bob)
    end

    it 'clones and re-emits messages' do
      expect {
        post :reemit, format: :json, params: { id: messages(:bob_website_agent_message).to_param, agent_id: agents(:bob_website_agent) }
      }.to change { Message.count }.by(1)
      expect(Message.last.payload).to eq(messages(:bob_website_agent_message).payload)
      expect(Message.last.agent).to eq(messages(:bob_website_agent_message).agent)
      expect(Message.last.created_at.to_i).to be_within(2).of(Time.now.to_i)
    end

    it 'can only re-emit Messages for the current user' do
      expect {
        post :reemit, format: :json, params: { id: messages(:jane_website_agent_message).to_param, agent_id: agents(:jane_website_agent) }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'DELETE destroy' do
    it 'only deletes messages for the current user' do
      sign_in users(:bob)
      expect {
        delete :destroy, format: :json, params: { id: messages(:bob_website_agent_message).to_param, agent_id: agents(:bob_website_agent) }
      }.to change { Message.count }.by(-1)

      expect {
        delete :destroy, format: :json, params: { id: messages(:jane_website_agent_message).to_param, agent_id: agents(:jane_website_agent) }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
