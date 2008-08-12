class PassengerStatus < Scout::Plugin
  def build_report
    cmd  = option(:passenger_memory_stats_command) || "passenger-memory-stats | grep \"FrameworkS\\|ApplicationS\\|Rails:\" | awk '{print $5,$6,$7,$8,$9}'"
    out = `#{cmd} 2>&1`
    if $?.success?
      parse_data(out)
    else
      error("Could not get data from command", "Error: #{data}")
    end
  end

  def parse_data(data)
    orgs = {}

    data.to_a.each { |line|
      if line.strip =~ %r|(\d+.\d).MB.(\w+(\s\w+)?):./var/www/rails/(\w+)/\w+| 
        m = Regexp.last_match
        orgs[m[4]] = {'rails_instance_count' => 0, 'total' => 0} unless orgs[m[4]]

        orgs[m[4]]['total'] += m[1].to_f 
        orgs[m[4]]['rails_instance_count'] += 1 unless m[3]
        orgs[m[4]][m[2]] ? orgs[m[4]][m[2]] += m[1].to_f : orgs[m[4]][m[2]] = m[1].to_f
      end
    }
    orgs.each_pair { |org,info|
      info.each_pair { |stat,value|
        report("#{org}_#{stat.sub(/\s/, '_').downcase}" => "#{value}")
      }
    }
  end
end

