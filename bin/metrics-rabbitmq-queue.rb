#!/usr/bin/env ruby
#
# RabbitMQ Queue Metrics
# ===
#
# Copyright 2011 Sonian, Inc <chefs@sonian.net>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'sensu-plugin/metric/cli'
require 'socket'
require 'carrot-top'

class RabbitMQMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :host,
         description: 'RabbitMQ management API host',
         long: '--host HOST',
         default: 'localhost'

  option :port,
         description: 'RabbitMQ management API port',
         long: '--port PORT',
         proc: proc(&:to_i),
         default: 15_672

  option :user,
         description: 'RabbitMQ management API user',
         long: '--user USER',
         default: 'guest'

  option :password,
         description: 'RabbitMQ management API password',
         long: '--password PASSWORD',
         default: 'guest'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to $queue_name.$metric',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.rabbitmq"

  option :filter,
         description: 'Regular expression for filtering queues',
         long: '--filter REGEX'

  option :ssl,
         description: 'Enable SSL for connection to the API',
         long: '--ssl',
         boolean: true,
         default: false

  def acquire_rabbitmq_queues
    begin
      rabbitmq_info = CarrotTop.new(
        host: config[:host],
        port: config[:port],
        user: config[:user],
        password: config[:password],
        ssl: config[:ssl]
      )
    rescue
      warning 'could not get rabbitmq queue info'
    end
    rabbitmq_info.queues
  end

  def run
    timestamp = Time.now.to_i
    acquire_rabbitmq_queues.each do |queue|
      if config[:filter]
        # #YELLOW
        unless queue['name'].match(config[:filter]) # rubocop:disable IfUnlessModifier
          next
        end
      end
      %w(messages).each do |metric|
        output([config[:scheme], queue['name'], metric].join('.'), queue[metric], timestamp)
      end
    end
    ok
  end
end
