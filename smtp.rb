#!/usr/bin/env ruby

require "net/smtp"

HOST = "localhost".freeze
PORT = 2526
FROM_ADDR = "".freeze
TO_ADDR = "".freeze

# rubocop:disable Layout/HeredocIndentation
message = <<EMAIL
From: =?UTF-8?Q?Jorg=C3=89ih?= <jorgei-laslkasdjfaslaksjdfaslkdjfsa@gmail.com
Date: Tue, 17 Dec 2024 11:03:40 +1100
Subject: outbound message
To: #{TO_ADDR}

This is an email body

EMAIL
# rubocop:enable Layout/HeredocIndentation

smtp = Net::SMTP.new(HOST, PORT)
smtp.disable_starttls
smtp.start do |s|
  s.send_message message, FROM_ADDR, TO_ADDR
end
