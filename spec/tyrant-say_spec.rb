require_relative 'test-common'

require 'cinch/plugins/tyrant-say'

describe Cinch::Plugins::TyrantSay do
  include Cinch::Test

  let(:bot) {
    make_bot(Cinch::Plugins::TyrantSay) { |c|
      self.loggers.each { |l| l.level = :fatal }
    }
  }

  it 'makes a test bot' do
    expect(bot).to be_a Cinch::Bot
  end

  before :each do
    @conn = FakeConnection.new
    @tyrant = Tyrants.get_fake('testplayer', @conn)
    allow(bot.plugins[0]).to receive(:is_superofficer?).and_return(true)
  end

  describe 'say' do
    before :each do
      expect(Tyrants).to receive(:get).with('testplayer').and_return(@tyrant)
      allow(message.user).to receive(:master?).and_return(false)
    end

    let(:message) { make_message(bot, '!say something', channel: '#test') }

    it 'says something' do
      # Abstraction leak here: I should not have to escape [, ], or /
      @conn.respond('postFactionMessage', 'text=\[IRC\/test\] something', {
        # lolwut why does Tyrant send nil?
        'result' => nil,
      })
      replies = get_replies_text(message)
      expect(replies).to be == ['test: Your message was posted.']
    end

    it 'handles failure to post' do
      # Abstraction leak here: I should not have to escape [, ], or /
      @conn.respond('postFactionMessage', 'text=\[IRC\/test\] something', {
        'result' => false,
      })
      replies = get_replies_text(message)
      expect(replies).to be == ['test: Your message was NOT posted.']
    end

    it 'warns for messages that are too long' do
      msg = make_message(bot, '!say ' + ('a') * 200, channel: '#test')
      allow(msg.user).to receive(:master?).and_return(false)
      replies = get_replies_text(msg)
      expect(replies).to be == ['test: Your message is too long. Remove 40 characters.']
    end
  end

  describe 'flood control' do
    def msg
      m = make_message(bot, '!say asdf', channel: '#test')
      allow(m.user).to receive(:master?).and_return(false)
      m
    end

    before :each do
      allow(Tyrants).to receive(:get).with('testplayer').and_return(@tyrant)
      # Abstraction leak here: I should not have to escape [, ], or /
      @conn.respond('postFactionMessage', 'text=\[IRC\/test\] asdf', {
        'result' => true,
      })
    end

    it 'warns on second' do
      get_replies(msg)
      replies = get_replies_text(msg)
      expect(replies).to be == ['test: Talking too often. Cool down a bit.']
    end

    it 'remains silent on third and fourth' do
      get_replies(msg)
      get_replies(msg)
      replies = get_replies_text(msg)
      expect(replies).to be == []

      replies = get_replies_text(msg)
      expect(replies).to be == []
    end
  end
end
