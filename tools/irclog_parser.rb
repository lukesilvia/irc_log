#!/usr/bin/env ruby -w

require 'csv'
require 'date'

# tc がtab 文字をを'' で囲って無視するためスペースに変換する
def quote_body(body)
  body.gsub("\t", ' ')
end

def extract_date_from_filename(filename)
  Date.parse(filename[/^\d{4}-\d{2}-\d{2}/])
end

# 09:29 Created at: 2008/09/22 07:22
DATE_REGEXP = %r|^\d{2}:\d{2} Created at: (\d{4}/\d{2}/\d{2})|

# 09:15 lukesilvia: ありがとうございます
STATUS_REGEXP = /^(\d{2}:\d{2}) (\w+?): (.+)$/

logfile_path = ARGV.shift
date = extract_date_from_filename(File.basename(logfile_path))
status_count = 0

begin
  File.open(logfile_path).readlines.each do |line|
    if STATUS_REGEXP =~ line
      time = $1
      nick = $2
      body = $3

      if nick != 'Mode'
        status_count += 1

        puts CSV.generate_line([
          (date.strftime('%Y%m%d') + sprintf('%05d', status_count)).to_i,
          'nick', nick,
          'body', quote_body(body),
          'date', date.strftime('%Y%m%d'),
          'time', time
        ], "\t")
      end
    end
  end
rescue Errno::EPIPE
end
