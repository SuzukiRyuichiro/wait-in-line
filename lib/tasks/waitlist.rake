namespace :waitlist do
  desc "Run the queue settler in a loop (the `scheduler` service)"
   task tick_forever: :environment do
     $stdout.sync = true # show logs immediately in `docker compose logs`
     interval = Float(ENV.fetch("TICK_INTERVAL_SECONDS", "1"))
     puts "[ticker] started, interval=#{interval}s"

     loop do
       # Rails.application.reloader.wrap runs one tick as a unit of work:
       #
       # - development: reloads changed files before each tick. Reloading
       #   normally happens per web request, and this loop has no requests, so
       #   without wrap it would keep running stale code until restarted.
       # - production: config.enable_reloading is false, so no reloading
       #   happens. wrap still runs the Rails executor (resets
       #   CurrentAttributes, clears the query cache, releases AR connections
       #   if any), which is cheap and harmless.
       #
       # sleep stays outside wrap on purpose: the reloader holds a lock while
       # active, and sleeping inside it could block reloading in other threads.
       Rails.application.reloader.wrap do
         # TODO: Waitlist::Settle.call
       end
       sleep interval
     end
   end
end
