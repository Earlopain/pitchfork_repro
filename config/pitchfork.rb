# frozen_string_literal: true

listen ENV.fetch('PITCHFORK_LISTEN_ADDRESS', '0.0.0.0:3001'), tcp_nopush: true, backlog: 2048
worker_processes ENV.fetch('PITCHFORK_WORKER_COUNT', 2).to_i

# Each worker will have its own copy of this data structure.
WorkerData = Data.define(:max_requests, :max_mem)
worker_data = nil

def worker_pss(pid)
  data = File.read("/proc/#{pid}/smaps_rollup")
  pss_line = data.lines.find { |line| line.start_with?('Pss:') }
  pss_line.split[1].to_i * 1024
end

after_worker_ready do |server, worker|
  max_requests = Random.rand(5_000..10_000)
  max_mem = Random.rand((386 * (1024**2))..(768 * (1024**2)))
  worker_data = WorkerData.new(max_requests:, max_mem:)

  server.logger.info("worker=#{worker.nr} gen=#{worker.generation} ready, serving #{max_requests} requests, #{max_mem} bytes")
end

after_request_complete do |server, worker, _env|
  if worker.requests_count > worker_data.max_requests
    server.logger.info("worker=#{worker.nr} gen=#{worker.generation}) exit: request limit (#{worker_data.max_requests})")
    exit
  end

  if worker.requests_count % 16 == 0
    pss_bytes = worker_pss(worker.pid)
    if pss_bytes > worker_data.max_mem
      server.logger.info("worker=#{worker.nr} gen=#{worker.generation}) exit: memory limit (#{pss_bytes} bytes > #{worker_data.max_mem} bytes), after #{worker.requests_count} requests")
      exit
    end
  end
end
