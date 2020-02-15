require 'digest'
require 'redis'

$stdout.sync = true
BATCH_SIZE_KEY = "batch_size"
BATCH_SIZE_DEFAULT = 10000000

SLEEP_KEY = "sleep"
SLEEP_DEFAULT_S=100

def redis
  Redis.new(host: ENV["REDIS_HOST"], port: ENV["REDIS_PORT"])
end

def batch_size
  raw = redis.get(BATCH_SIZE_KEY) || BATCH_SIZE_DEFAULT
  puts "got batch size: #{raw}"
  raw.to_i
end

def sleep_s
  raw = redis.get(SLEEP_KEY) || SLEEP_DEFAULT_S
  puts "got sleep seconds: #{raw}"
  raw.to_i
end

def idle
  s = sleep_s
  print "Sleeping for #{s}s ..."
  sleep(s)
  puts "done"
end

def do_work(num)
  return idle if num < 1

  print "Making #{num} hashes..."
  (1..num).each do
    Digest::SHA2.hexdigest 'abc'
  end
  puts "done"
end

def mainloop
  while true do
    do_work batch_size
  end
end

begin
  puts "Running"
  mainloop
rescue Object => e
  # shut down w/o error
  puts e.message
end

