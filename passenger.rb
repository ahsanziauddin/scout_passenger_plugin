class PassengerStatus < Scout::Plugin

  def build_report
    cmd = option(:passenger_command) || "passenger-memory-stats 2> /dev/null"
    aroot = option(:application_root) || "/var/www/rails/"
    aname = option(:application_name) 

    out = `#{cmd} 2>&1`
    if $?.success?
      parse_data(out, aroot, aname)
    else
      error("Could not get data from command", "Error: #{data}")
    end
  end

  def parse_data(data, app_root, app_name)
    apps = {}

    data.to_a.each { |line|
      # PID    PPID   Threads  VMSize    Private  Name
      # 18419  1      1        131.8 MB  0.1 MB   /usr/sbin/apache2 -k start
      # 11252  18419  1        226.5 MB  1.5 MB   /usr/sbin/apache2 -k start
      # 
      # apache line: (vmsize, rss and name) are (m[4], m[5], m[6])
      if line.strip =~ %r|(\d+)\s+(\d+)\s+(\d+)\s+(\d+\.\d)\sMB\s+(\d\.\d)\sMB\s+(/.*)$|
        m = Regexp.last_match

        apps['apache'] = { 'processes' => 0, 
                           'total_dirty_rss' => 0.0,
                           'total_vm_size' => 0.0 } unless apps['apache']

        apps['apache']['processes'] += 1
        apps['apache']['total_dirty_rss'] += m[5].to_f
        apps['apache']['total_vm_size'] += m[4].to_f
      end

      # PID    Threads  VMSize   Private  Name
      # 2615   1        89.3 MB   27.2 MB  Passenger FrameworkSpawner: /var/www/rails/app/r*
      # 3336   1        119.5 MB  25.3 MB  Passenger ApplicationSpawner: /var/www/rails/app/r*
      # 3338   1        127.5 MB  27.0 MB  Rails: /var/www/rails/app/r*
      #
      # passenger line: (vmsize, rss and name) are (m1[3], m1[4], m1[5])
      if line.strip =~ /(\d+)\s+(\d+)\s+(\d+\.\d)\sMB\s+(\d+\.\d)\sMB\s+([Rails|Passenger].*)$/
        m1 = Regexp.last_match

        # only passenger name so (appname, type and subtype) are (m2[3], m2[1], m2[2]) 
        if m1[5].to_s =~ %r|(\w+(\s\w+)?):.#{app_root}(\w+)/\w+|
          m2 = Regexp.last_match

          apps[m2[3]] = { 'instances' => 0, 
                          'total_dirty_rss' => 0.0, 
                          'total_vm_size' => 0.0 } unless apps[m2[3]]

          apps[m2[3]]['instances'] += 1 unless m2[2]
          apps[m2[3]]['total_dirty_rss'] += m1[4].to_f 
          apps[m2[3]]['total_vm_size'] += m1[3].to_f 

          type = m2[1].sub(/\s/, '_').downcase
          apps[m2[3]][type] ? apps[m2[3]][type] += m1[4].to_f : apps[m2[3]][type] = m1[4].to_f
        end
      end
    }

    if app_name and apps[app_name]
      report(apps[app_name])
    else
      report(apps)
    end

  end
end


