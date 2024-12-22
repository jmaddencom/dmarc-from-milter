require "resolv-replace"
require "dmarc"
require "mail"
require "milter"
require "yaml"

OPTS = YAML.load_file(File.join(File.dirname(__FILE__), "../config.yml")).to_h || abort

class Dmilter < Milter::Milter
  def initialize
    @modified_from = nil
    super
  end

  def header(key, value)
    if key == "From"
      cleared_from = DmarcFilter.new.eval(value)
      @modified_from = cleared_from if cleared_from != value
    end
    Response.continue
  end

  def end_body(_args)
    if @modified_from
      warn "modifying from header to #{@modified_from}"
      return [Response.change_header("From", @modified_from), Response.continue]
    end
    Response.continue
  end
end

class DmarcFilter
  def eval(from_header)
    begin
      address = Mail::Address.new(from_header)
      domain = address.domain
    rescue Mail::Field::IncompleteParseError
      warn "Failure to parse the From header value, assuming dmarc without evidence"
      warn "Header: #{from_header}"
      assume_dmarc = true
    end

    return fixed_from(from_header) if assume_dmarc || dmarc?(domain)

    from_header
  end

  def fixed_from(email)
    begin
      a = Mail::Address.new(email)
      a.format
    rescue Mail::Field::IncompleteParseError
      warn "Error parsing email #{email}, returning failsafe"
      return OPTS["dmarc_from_address"]
    end
    a.display_name = a.local if a.display_name.nil?
    a.address = OPTS["dmarc_from_address"]
    a.encoded
  end

  def dmarc?(domain)
    tries = 0
    begin
      r = DMARC::Record.query(domain)
    # rubocop:disable Style/RescueStandardError
    # because I don't know #query might encounter
    rescue
      tries += 1
      sleep 0.2
      retry if tries < 5
      return true
    end
    # rubocop:enable Style/RescueStandardError

    return false if r.nil?

    r.p.to_s == "reject" ||
      r.p.to_s == "quarantine" ||
      r.aspf.to_s == "s" ||
      r.adkim.to_s == "s" ||
      r.sp.to_s == "reject" ||
      r.sp.to_s == "quarantine" ||
      OPTS["other_bad_domains"].include?(domain)
  end
end

Milter.register(Dmilter)
Milter.start unless ENV["RACK_ENV"] == "test"
