#!/usr/bin/env ruby
# encoding: utf-8
# LogFile -- ODDB -- 21.10.2003 -- hwyss@ywesee.com

require 'util/oddbconfig'
require 'date'
require 'fileutils'

module ODDB
	module LogFile
		LOG_ROOT = File.expand_path('log', PROJECT_ROOT)
		def append(key, line, time=Time.now.utc)
			file = filename(key, time)
			dir = File.dirname(file)
			FileUtils.mkdir_p(dir)
			timestr = time.strftime('%Y-%m-%d %H:%M:%S %Z')
			File.open(file, 'a') { |fh| fh << [timestr, line, "\n"].join }
		end
		def filename(key, time)
			path = [
				key,
				time.year,
				sprintf('%02i', time.month) + '.log',
			].join('/')
			File.expand_path(path, LOG_ROOT)
		end
		def read(key, time)
			begin
				File.read(filename(key, time))
			rescue(StandardError)
				''
			end
		end
    def debug(msg)
      msg = "#{caller[0]}: #{msg}"
      $stdout.puts Time.now.to_s + ': ' + msg; $stdout.flush
      if not defined?(@@debugLog) or not @@debugLog
        name = LogFile.filename('oddb/debug', Time.now)
        FileUtils.makedirs(File.dirname(name))
        @@debugLog = File.open(name, 'a+')
      end
      @@debugLog.puts("#{Time.now}: #{msg}")
      @@debugLog.flush
    end
		module_function :append
		module_function :filename
		module_function :read
    module_function :debug
	end
end
