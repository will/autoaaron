# frozen_string_literal: true
require "dotenv/load"
require "twitter"
require "redis"

module AutoAaron
  extend self
  REDIS = Redis.new(url: ENV["REDIS_URL"] || "redis://localhost")
  DEFAULT_SINCE = 967815970805964800
  KEY = "aaron"
  EMOJI = %w[🤡 🙄 🙃 🤣 😹 ❣️]

  CLIENT = Twitter::REST::Client.new do |config|
    config.consumer_key        = ENV["CONSUMER_KEY"]
    config.consumer_secret     = ENV["CONSUMER_SECRET"]
    config.access_token        = ENV["ACCESS_TOKEN"]
    config.access_token_secret = ENV["ACCESS_SECRET"]
  end

  def aaron!
    since = get_since
    results = get_tweets since

    results.each { |t| reply_to t }

    set_since(results.map(&:id).max || since)
  end

  def get_tweets(since)
    CLIENT.user_timeline(
      "tenderlove",
      since_id:        since,
      include_rts:     false,
      count:           1000,
      exclude_replies: true,
      trim_user:       true,
    ).reject { |t|
      t.full_text =~ /@/
    }
  end

  def get_since
    (REDIS.get(KEY) || DEFAULT_SINCE).to_i
  end

  def set_since(since)
    REDIS.set KEY, since
  end

  def reply_to(t)
    return unless rand > 0.5 || t.lang == "ja"
    r = response_for(t)
    puts %Q(response=#{r.inspect} id=#{t.id} lang=#{t.lang} text=#{t.full_text.inspect})
    if ENV["LIVE"]
      CLIENT.update("@tenderlove #{r}", in_reply_to_status: t)
    end
  end

  def response_for(t)
    text = t.lang == "ja" ? "アーロン" : "aaron"
    len = t.full_text.size
    text = text[0]*3 + text   if len > 90
    text = text + text[-1]*10 if len > 140

    text = "…" + text if rand > 0.9
    text = text + (rand > 0.5 ? "!" : '.') if rand > 0.9
    text = text + " #aaron" if rand > 0.9
    text = text + " " + EMOJI.sample if rand > 0.9

    return text
  end
end

