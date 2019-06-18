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

  CLIENT = Twitter::REST::Client.new { |config|
    config.consumer_key        = ENV["CONSUMER_KEY"]
    config.consumer_secret     = ENV["CONSUMER_SECRET"]
    config.access_token        = ENV["ACCESS_TOKEN"]
    config.access_token_secret = ENV["ACCESS_SECRET"]
  }

  def aaron!
    since = get_since
    results = get_tweets since

    results.each { |t| reply_to(t) unless rand > 0.95 }

    set_since(results.map(&:id).max || since)
  end

  def force(id)
    t = CLIENT.status id
    set_since([id, get_since].max)
    reply_to t
  end

  def get_tweets(since)
    CLIENT.user_timeline(
      "tenderlove",
      since_id: since,
      include_rts: false,
      count: 1000,
      exclude_replies: true,
      trim_user: true,
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
    r = response_for(t)
    puts %(response=#{r.inspect} id=#{t.id} lang=#{t.lang} text=#{t.full_text.inspect})
    if ENV["LIVE"]
      CLIENT.update("@tenderlove #{r}", in_reply_to_status: t)
    end
  end

  def response_for(t)
    text = t.lang == "ja" ? "アーロン" : "aaron"
    len = t.full_text.size
    text = text[0] * 3 + text if len > 90
    text += text[-1] * 10 if len > 140

    text = "…" + text if rand > 0.9
    text += (rand > 0.5 ? "!" : ".") if rand > 0.9
    text += " #aaron" if rand > 0.9
    text = text + " " + EMOJI.sample if rand > 0.9

    text
  end
end
