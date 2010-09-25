# -*- coding: utf-8 -*-

require 'rubygems'
require 'sinatra'
require 'tokyocabinet'
require 'date'

set :views, File.expand_path(File.dirname(__FILE__)) + '/views'
set :public, File.expand_path(File.dirname(__FILE__)) + '/public'

class Status < Struct.new(:id, :name, :nick, :body, :date, :time)
  DATA_FILE_PATH = File.expand_path(File.dirname(__FILE__)) + '/data/irclog.tct'
  include TokyoCabinet

  def self.find(conditions, options = {})
    tdbopen(DATA_FILE_PATH) do |tdb|
      qry = TDBQRY.new(tdb)

      # ignore bot statuses
      conditions += [['nick', 'NOT QCSTROR', 'hammer plaggerbot']]

      conditions.each do |cond|
        column        = cond[0]
        operation_str = cond[1].clone
        value         = cond[2]
        
        if operation_str.gsub!(/not /i, '')
          operation = (TDBQRY.const_get(operation_str) | TDBQRY::QCNEGATE)
        else
          operation = TDBQRY.const_get(operation_str)
        end

        qry.addcond(column, operation, value)
      end

      if o = options[:order]
        o = Array(o)

        if type = (o)[1]
          o = [o[0], TDBQRY.const_get(type)]
        end

        qry.setorder(*o)
      else
        qry.setorder('')
      end

      qry.setlimit(options[:limit] || 1000)

      ids = qry.search

      ids.map{|id| 
        record = tdb.get(id) 
        new(id, *record.values_at('name', 'nick', 'body', 'date', 'time'))
      }
    end
  end

  private

  def self.tdbopen(path)
    begin
      tdb = TDB.new
      tdb.open(path, TDB::OREADER)
  
      yield(tdb)
    ensure
      tdb.close
    end
  end
end

class Page
  attr_reader :date

  def self.create(date)
    case date
    when Date
      new(date)
    when String
      new(Date.parse(date))
    else
      raise ArgumentError
    end
  end

  def initialize(date)
    @date = date
  end

  def _next
    self.class.new(@date + 1)
  end

  def _prev
    self.class.new(@date - 1) 
  end
end

get '/' do
  @statuses = []

  current_date_path = "/#{Date.today.strftime('%Y%m%d')}"
  redirect current_date_path
end

get %r{^/(\d{8})$} do |date|
  @date     = Date.parse(date)
  @statuses = Status.find([['date', 'QCSTREQ', date]])

  erb :index
end

get '/users/:nick' do |date|
  @statuses = 
    !(n = params[:nick]).empty? ?
      Status.find([['nick', 'QCSTREQ', params[:nick]]], :order => ['', 'QONUMDESC']) :
      []

  erb :index
end

get '/search' do
  @statuses = 
    !(q = params[:q]).empty? ? Status.find([['body', 'QCFTSAND', q]]) : []
  
  erb :index
end

helpers do
  include Rack::Utils

  alias_method :h, :escape_html

  def date_link(date)
    page = Page.create(date)

    [
      page._prev ? '<a href="/' + page._prev.date.strftime('%Y%m%d') + '">&lt;</a>' : '<span class="date_link_off">&lt;</span>',
      h(page.date.strftime('%Y-%m-%d')),
      page._next ? '<a href="/' + page._next.date.strftime('%Y%m%d') + '">&gt;</a>' : '<span class="date_link_off">&gt;</span>',
    ].join('&nbsp;')
  end

  def status_line(status, with_date = true)
    result = []
    
    if with_date
      result << %Q|<a href="/#{h(status.date)}##{h(status.id)}">#{h(status.date)}</a>|
    end

    result << h(status.time)
    result << %Q|(<a href="/users/#{h(status.nick)}">#{h(status.nick)}</a>)|
    result << h(status.body)

    %Q|<span id="#{status.id}" class="status_body">#{result.join(' ')}</span>|
  end
end
