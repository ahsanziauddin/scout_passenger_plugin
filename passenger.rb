class PassengerStatus < Scout::Plugin
  def build_report
    begin
      orgs = {}
      out = `passenger-memory-stats | grep "FrameworkS\\|ApplicationS\\|Rails:" | awk '{print $5,$6,$7,$8,$9}'`

      out.to_a.each { |line|
	if line.strip =~ %r|(\d+.\d).MB.(\w+(\s\w+)?):./var/www/rails/(\w+)/\w+| 
          m = Regexp.last_match
          orgs[m[4]] = {'Rails Instance Count' => 0, 'Total' => 0} unless orgs[m[4]]

          orgs[m[4]]['Total'] += m[1].to_f 
          orgs[m[4]]['Rails Instance Count'] += 1 unless m[3]
          orgs[m[4]][m[2]] ? orgs[m[4]][m[2]] += m[1].to_f : orgs[m[4]][m[2]] = m[1].to_f
	end
      }
      orgs.each_pair { |org,info|
	info.each_pair { |stat,value|
          report("#{org} - #{stat.downcase}" => "#{value}")
	}
      }
    rescue
      error(:subject => "Couldn't run the plugin",
            :body    => "An exception was thrown #{$!.inspect}")
    end
  end
end

