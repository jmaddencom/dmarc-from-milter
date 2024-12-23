# dmarc-from-milter
A milter for ESPs that replaces From headers in outbound mail for recipients using DMARC

## Why?
Read up on DMARC, SPF, and DKIM elsewhere -- I'm no expert. (I try to write clean ruby and it's my preferred language but I'm also no ruby expert.)

If you're an ESP such as a mailing list provider you generally send email on behalf of subscribers posting to a list by maintaining their original `From` header but injecting your own envelope sender. DMARC breaks this behavior and one of the workarounds suggested to such hosts is to change the From header to something the host owns. 

That's what this milter does. Receiving mail from your MTA it checks `From` headers' domains and modifies those that would reject, quarantine, or otherwise de-prioritize incoming mail with their domain in the `From` header.

This milter is how DMARC mitigation is done at [FreeLists](https://www.freelists.org)

## Installation
1. dmarc-from-milter is written in ruby and I like RVM, so first head over to [rvm.to](https://rvm.io) and install that on the machine you intend to run the milter.
1. `git clone` the repo to the directory you'd like the software to run from
    - The default location is /home. If you change this, update the location in `dmarc-milter.service` before installing it.
1. Install dependencies with `bundle install`
1. Make sure you have port 8888 on `localhost` available. I'll make this configurable in the future.
1. `cp config.template config.yml` and set your site's settings. At least `dmarc_from_address` is mandatory.
1. Add a user to run the milter. The default is "dmarc" and if you use anything else, set that user in the `dmarc-milter.service` file.
1. `cp dmarc-milter.service /etc/systemd/system/` This may vary by your distribution, and you may want to store this somewhere else. `systemctl daemon-reload`
1. Start the service and make sure it's running. `systemctl start dmarc-milter` and `journalctl -u dmarc-milter.service`
1. Configure your MTA. Here's a config block for Postfix, add this to `/etc/postfix/master.cf` or wherever you keep your master.cf. This runs an smtpd on localhost:2525.
    ```
    127.0.0.1:2525 inet n   -       y       -       -       smtpd
        -o syslog_name=postfix/dmarc_milter
        -o smtpd_recipient_restrictions=permit_mynetworks,reject
        -o mynetworks=127.0.0.0/8
        -o smtpd_milters=inet:127.0.0.1:8888
        -o milter_protocol=6
        -o milter_default_action=reject
    ```
1. Verify outbound mail is properly filtered. See `smtp.rb` for an example test.
1. Configure the outbound mail process you'd like filtered at this new smtpd on 127.0.0.1:2525.

# Running tests
You might also run the test suite to ensure things are working at least on the surface: `rake test`

# Contributing
- Feel free to submit a PR
- Run `rubocop` before committing and fix any issues. This will eventually be part of the build process, I just haven't automated it yet.
