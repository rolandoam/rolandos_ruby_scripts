#!/usr/bin/env ruby

require 'fileutils'

# Incremental backup script (AKA poor man's Time Machine). Place it
# somewhere safe, create a new partition mounted by default read-only,
# set it as the BACKUP_DEST in the script below.
#
# The script should be run as root
#
# Sample crontab for root:
#
#   # m h  dom mon dow   command
#   0  3 * * *   /home/samba/backup.rb daily > /dev/null
#   30 3 * * 1   /home/samba/backup.rb weekly > /dev/null
#
# This will run the daily backup every day at 03:00AM and every weekly
# backup on mondays at 03:00 AM.
#
# comments/questions:
#
#   http://rolando.cl
#
# For more info on the technique used by this script:
#
#   http://www.mikerubel.org/computers/rsync_snapshots/
class Backup
  include FileUtils

  BACKUP_DEST     = "/snapshots"
  BACKUP_DIRNAME  = "Respaldos"
  DAILY_LAST      = 6 # keep upto 7 (6.downto(0)) daily backups

  def daily(dirs)
    backup(dirs, "daily", DAILY_LAST)
  end

  def weekly(dirs)
    backup(dirs, "weekly")
  end

  private
  # incrementaly backup dirs with prefix, keep upto +keep+ copies
  def backup(dirs, prefix, keep = 4)
    write_snapshots(false) do
      dirs.sort.each { |dir|
        target = File.basename(dir)
        puts "#{prefix} incremental backup for #{target}"
        # prepare backup dir
        backup_dir = "#{BACKUP_DEST}/#{target}"
        mkdir_p backup_dir
        # roll the backups
        rm_rf "#{backup_dir}/#{prefix}.#{keep}"
        keep.downto(0) do |k|
          mv "#{backup_dir}/#{prefix}.#{k-1}", "#{backup_dir}/#{prefix}.#{k}" if File.exists?("#{backup_dir}/#{prefix}.#{k-1}")
        end
        # create the most recent backup
        if prefix == "weekly"
          # copy daily.DAILY_LAST and keep it as the first weekly
          system("cp -al #{backup_dir}/daily.#{DAILY_LAST} #{backup_dir}/weekly.0") if File.exists?("#{backup_dir}/daily.#{DAILY_LAST}")
        else
          # copy daily, perform as usual
          system("cp -al #{backup_dir}/#{prefix}.0 #{backup_dir}/#{prefix}.1") if File.exists?("#{backup_dir}/#{prefix}.0")
          # before rsync, remove the symlink
          rm_f "#{dir}/#{BACKUP_DIRNAME}"
          system("rsync -a --delete #{dir}/ #{backup_dir}/#{prefix}.0")
          # create the symlink again
          ln_s "#{BACKUP_DEST}/#{target}", "#{dir}/#{BACKUP_DIRNAME}"
        end
      }
    end
  end

  # perform changes on the snapshots mount point. This will create a
  # small window of insecurity. Check the reference (above) on how to
  # overcome this.
  def write_snapshots(email, &block)
    begin
      system("mount -o remount,rw #{BACKUP_DEST}")
      yield
    ensure
      system("mount -o remount,ro #{BACKUP_DEST}")
      if email
        # here we could send an email to the admin, notifying that the
        # backup was made (not yet implemented!)
      end
    end
  end
end

if __FILE__ == $0
  if Process.euid != 0
    puts "must be run as root!!"
    exit(1)
  end
  if ARGV.size != 1 || !%w(daily weekly).include?(ARGV[0])
    puts "usage: #{$0} [daily|weekly]"
    exit(1)
  end

  b = Backup.new
  if ENV['DEBUG']
    dirs = ["/home/rolando"]
  else
    # you might want to change this
    dirs = Dir["/winhome/users/*"]
  end
  b.send(ARGV[0], dirs)
end
