require "simplecov"
SimpleCov.start do
  enable_coverage :branch
end

require "minitest/autorun"
require "mocha/minitest"
require "yaml"

ENV["RACK_ENV"] = "test"
require_relative "../lib/dmilter"

class DmarcFilterTest < Minitest::Test
  def setup
    @dmf = DmarcFilter.new
    @our_address = YAML.load_file(File.join(File.dirname(__FILE__), "../config.yml")).to_h["dmarc_from_address"]
  end

  def test_dmarc_various_domains
    assert @dmf.dmarc?("gmail.com")
    assert @dmf.dmarc?("aol.com")
    refute @dmf.dmarc?("freelists.org")
  end

  def test_dmarc_bad_domains
    ok_dmarc_record = DMARC::Record.new({ v: :DMARC1, p: nil, rua: nil })
    DMARC::Record.expects(:query).with("some-domain-that-acts-like-dmarc.tld").returns(ok_dmarc_record)

    assert @dmf.dmarc?("some-domain-that-acts-like-dmarc.tld")
  end

  def test_dmarc_nxdomain
    refute @dmf.dmarc?("lkasdjfalskdfjasldfkjasdlkfjsadflksaj.alskajfsaljd")
  end

  def test_dmarc_retries_query_failure_eventually_returns_true
    DMARC::Record.expects(:query).with("some-domain.tld").raises.times(5)
    dmf = DmarcFilter.new
    dmf.expects(:sleep).times(5).returns nil

    assert dmf.dmarc?("some-domain.tld")
  end

  # NOTE: fixed_from is only called when the domain uses dmarc so the address is always @our_address
  def test_fixed_from_dmarcs_invalid_from
    dmf = DmarcFilter.new
    dmf.expects(:warn)

    assert_equal @our_address, dmf.fixed_from("invalid_fromline@some-domain.tld>")
  end

  def test_fixed_from_dmarcs
    dmf = DmarcFilter.new
    dmf.expects(:warn).never

    assert_equal "Jane Doe <#{@our_address}>", dmf.fixed_from("Jane Doe <jdoe@aol.com>")
  end

  def test_fixed_from_adds_missing_display_name
    assert_equal "jdoe <#{@our_address}>", @dmf.fixed_from("jdoe@aol.com")
  end

  def test_fixed_from_returns_encoded_utf8_address
    assert_equal "=?UTF-8?B?SsO2cmc=?= <#{@our_address}>", @dmf.fixed_from("Jörg <jorg@gmail.com>")
    assert_equal "=?UTF-8?B?SsO2cmc=?= <#{@our_address}>",
                 @dmf.fixed_from("=?UTF-8?B?SsO2cmc=?= <jorg@some-domain.tld>")
  end

  def test_eval_calls_correct_domain
    dmf = DmarcFilter.new
    dmf.expects(:warn).never
    dmf.expects(:dmarc?).with("gmail.com").returns(true)

    assert_equal "Jane Doe <#{@our_address}>", dmf.eval("Jane Doe <jdoe@gmail.com>")
  end

  def test_eval_fixes_invalid_from_header
    dmf = DmarcFilter.new
    dmf.expects(:warn).times(3)
    dmf.expects(:dmarc?).never

    assert_equal @our_address, dmf.eval("invalid_fromline@some-domain.tld>")
  end
end
