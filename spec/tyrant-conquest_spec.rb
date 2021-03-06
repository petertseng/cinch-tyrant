require_relative 'test-common'

require 'cinch/plugins/tyrant-conquest'

describe Cinch::Plugins::TyrantConquest do
  include Cinch::Test

  let(:bot) {
    make_bot(Cinch::Plugins::TyrantConquest) { |c|
      self.loggers.each { |l| l.level = :fatal }
    }
  }

  before :each do
    @conn = FakeConnection.new
    @tyrant = Tyrants.get_fake('testplayer', @conn)
    allow(Tyrants).to receive(:get) { |n|
      raise "Who is #{n}?" unless n == 'testplayer'
      @tyrant
    }
  end

  it 'makes a test bot' do
    expect(bot).to be_a Cinch::Bot
  end

  context 'without arguments' do
    let(:message) { make_message(bot, '!tiles', channel: '#test') }

    it 'shows invasions' do
      allow(bot.plugins[0]).to receive(:map_hash).and_return({
        '1' => make_tile(1, 1001, 1000),
        '2' => make_tile(2),
      })
      replies = get_replies_text(message)
      expect(replies.shift).to be =~
        /^1 \(  0,   0\) faction 1000 vs faction 1001, -\d+:\d\d:\d\d left, CR: 1$/
      expect(replies).to be == []
    end

    it 'shows defenses' do
      allow(bot.plugins[0]).to receive(:map_hash).and_return({
        '1' => make_tile(1, 1000, 1001),
        '2' => make_tile(2),
      })
      replies = get_replies_text(message)
      expect(replies.shift).to be =~
        /^1 \(  0,   0\) faction 1001 vs faction 1000, -\d+:\d\d:\d\d left, CR: 1$/
      expect(replies).to be == []
    end

    it 'shows uncontested tiles' do
      allow(bot.plugins[0]).to receive(:map_hash).and_return({
        '1' => make_tile(1, 1000, cr: 2),
        '2' => make_tile(2),
      })
      replies = get_replies_text(message)
      expect(replies).to be == [
        'faction 1000\'s uncontested tiles (1, 2 CR): Use -v to list'
      ]
    end

    it 'informs us if we have no tiles on the map' do
      allow(bot.plugins[0]).to receive(:map_hash).and_return({
        '1' => make_tile(1, 1001, cr: 2),
        '2' => make_tile(2),
      })
      replies = get_replies_text(message)
      expect(replies).to be == [
        'Faction 1000 is not on the map'
      ]
    end
  end

  context 'with -v argument' do
    let(:message) { make_message(bot, '!tiles -v', channel: '#test') }

    it 'lists uncontested tiles' do
      allow(bot.plugins[0]).to receive(:map_hash).and_return({
        '1' => make_tile(1, 1000, cr: 2),
        '2' => make_tile(2),
      })
      replies = get_replies_text(message)
      expect(replies).to be == [
        'faction 1000\'s uncontested tiles (1, 2 CR):    1 (  0,   0)'
      ]
    end
  end

  context 'with name of a faction' do
    let(:message) { make_message(bot, '!tiles faction 1001', channel: '#test') }

    it 'lists tiles of that faction' do
      allow(bot.plugins[0]).to receive(:map_hash).and_return({
        '1' => make_tile(1, 1001, cr: 2),
        '2' => make_tile(2),
      })
      replies = get_replies_text(message)
      expect(replies).to be == [
        'faction 1001\'s uncontested tiles (1, 2 CR): Use -v to list'
      ]
    end

    it 'lists tiles that faction is attacking' do
      allow(bot.plugins[0]).to receive(:map_hash).and_return({
        '1' => make_tile(1, 1000, 1001, cr: 2),
        '2' => make_tile(2),
      })
      replies = get_replies_text(message)
      expect(replies.shift).to be =~
        /1 \(  0,   0\) faction 1001 vs faction 1000, -?\d+:\d\d:\d\d left, CR: 2/
        expect(replies).to be == []
    end

    it 'complains if no faction with that name exists' do
      allow(bot.plugins[0]).to receive(:map_hash).and_return({
        '1' => make_tile(1, 1000, cr: 2),
        '2' => make_tile(2),
      })
      replies = get_replies_text(message)
      expect(replies).to be == [
        'Faction faction 1001 is not on the map'
      ]
    end
  end

  context 'with ID of a faction' do
    let(:message) { make_message(bot, '!tiles 1001', channel: '#test') }

    it 'lists tiles of that faction' do
      allow(bot.plugins[0]).to receive(:map_hash).and_return({
        '1' => make_tile(1, 1001, cr: 2),
        '2' => make_tile(2),
      })
      replies = get_replies_text(message)
      expect(replies).to be == [
        'faction 1001\'s uncontested tiles (1, 2 CR): Use -v to list'
      ]
    end

    it 'complains if no faction with that ID exists' do
      allow(bot.plugins[0]).to receive(:map_hash).and_return({
        '1' => make_tile(1, 1000, cr: 2),
      })
      replies = get_replies_text(message)
      expect(replies).to be == [
        'Faction 1001 is not on the map'
      ]
    end
  end

  context 'with ID 0 (neutral tiles)' do
    before :each do
      allow(bot.plugins[0]).to receive(:map_hash).and_return({
        '1' => make_tile(1, 1001, cr: 2),
        '2' => make_tile(2, cr: 1),
        '3' => make_tile(3, cr: 3),
        '4' => make_tile(4, cr: 3),
      })
    end

    it 'lists neutral tiles' do
      replies = get_replies_text(make_message(bot, '!tiles 0', channel: '#test'))
      expect(replies).to be == [
        'There are 3 neutral tiles totaling 7 CR. 1 CR: 1, 3 CR: 2'
      ]
    end

    it 'lists neutral tiles with -v' do
      replies = get_replies_text(make_message(bot, '!tiles -v 0', channel: '#test'))
      expect(replies).to be == [
        'There are 3 neutral tiles totaling 7 CR. 1 CR: 1, 3 CR: 2',
        '   2 (  0,   0);    3 (  0,   0);    4 (  0,   0)',
      ]
    end
  end
end
