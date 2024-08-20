require 'rails_helper'

# using rspec "subject" one-liner shortcut which normally I hate, but it just saved
# so much typing here, where it's simple.

describe CompactUserAgent do
  subject { CompactUserAgent.new(user_agent).compact }

  describe "bad user agent" do
    let(:user_agent) { "bad value" }
    it { is_expected.to eq "bad_value" }
  end

  describe "long bad user agent" do
    let(:user_agent) { "a quite very long and terrible value that is very very long" }
    # truncates
    it { is_expected.to eq "a_quite_very_long_and_terrible_value_that_is_very_" }
  end

  describe "nil user agent" do
    let(:user_agent) { nil }
    it { is_expected.to eq nil }
  end

  describe "googlebot mobile" do
    let(:user_agent) { %q{Mozilla/5.0 (Linux; Android 6.0.1; Nexus 5X Build/MMB29P) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2272.96 Mobile Safari/537.36 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)} }
    it { is_expected.to eq "bot:Googlebot/Chrome_Mobile-41/Android-6.0/Nexus_5X"}
  end

  describe "yandex bot" do
    let(:user_agent) { %q{Mozilla/5.0 (compatible; YandexBot/3.0; +http://yandex.com/bots)} }
    it { is_expected.to eq "bot:Yandex_Bot"}
  end

  describe "baidu bot" do
    let(:user_agent) { %q{Mozilla/5.0 (compatible; Baiduspider/2.0;+http://www.baidu.com/search/spider.html)} }
    it { is_expected.to eq "bot:Baidu_Spider"}
  end

  describe "IE" do
    let(:user_agent) { %q{Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; FSL 7.0.6.01001)} }
    it { is_expected.to eq "Internet_Explorer-6/Windows-XP" }
  end

  describe "linux firefox" do
    let(:user_agent) { %q{Mozilla/5.0 (X11; U; Linux x86_64; de; rv:1.9.2.8) Gecko/20100723 Ubuntu/10.04 (lucid) Firefox/3.6.8} }
    it { is_expected.to eq "Firefox-3/Ubuntu-10.04"}
  end

  describe "MacOS safari" do
    let(:user_agent) { %q{ Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Safari/605.1.15} }
    it { is_expected.to eq "Safari-14/Mac-10.15" }
  end

  describe "iOS safari" do
    let(:user_agent) { %q{Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Mobile/15E148 Safari/604.1} }
    it { is_expected.to eq "Mobile_Safari-14/iOS-14.7/iPhone"}
  end

  describe "Opera Samsung" do
    let(:user_agent) { %q{Mozilla/5.0 (Linux; Android 10; SM-G970F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.4577.62 Mobile Safari/537.36 OPR/63.3.3216.58675} }
    it {is_expected.to eq "Opera_Mobile-63/Android-10/Galaxy_S10e"}
  end

  describe "Edge Windows" do
    let(:user_agent) { %q{Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.4577.63 Safari/537.36 Edg/93.0.961.38} }
    it { is_expected.to eq "Microsoft_Edge-93/Windows-10" }
  end
end
