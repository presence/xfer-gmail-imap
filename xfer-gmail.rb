#!/usr/bin/env ruby
require 'net/imap'

# Source server connection info.
SOURCE_HOST = 'imap.gmail.com'
SOURCE_PORT = 993
SOURCE_SSL  = true
SOURCE_USER = 'uname@domain'
SOURCE_PASS = 'passwd'

# Destination server connection info.
DEST_HOST = 'imap.gmail.com'
DEST_PORT = 993
DEST_SSL  = true
DEST_USER = 'uname@domain'
DEST_PASS = 'passwd'

# Mapping of source folders to destination folders. The key is the name of the
# folder on the source server, the value is the name on the destination server.
# Any folder not specified here will be ignored. If a destination folder does
# not exist, it will be created.
FOLDERS = {
  'INBOX' => 'INBOX',
  'Travel' => 'Travel',
  'sourcefolder' => 'destinationfolder'
}

# Utility methods.
def dd(message)
   puts "[#{DEST_HOST}] #{message}"
end

def ds(message)
   puts "[#{SOURCE_HOST}] #{message}"
end

# Connect and log into both servers.
ds 'connecting...'
source = Net::IMAP.new(SOURCE_HOST, SOURCE_PORT, SOURCE_SSL)

ds 'logging in...'
source.login(SOURCE_USER, SOURCE_PASS)

dd 'connecting...'
dest = Net::IMAP.new(DEST_HOST, DEST_PORT, DEST_SSL)

dd 'logging in...'
dest.login(DEST_USER, DEST_PASS)

# Loop through folders and copy messages.
FOLDERS.each do |source_folder, dest_folder|
  # Open source folder in read-only mode.
  begin
    ds "selecting folder '#{source_folder}'..."
    source.examine(source_folder)
  rescue => e
    ds "error: select failed: #{e}"
    next
  end
  
  # Open (or create) destination folder in read-write mode.
  begin
    dd "selecting folder '#{dest_folder}'..."
    dest.select(dest_folder)
  rescue => e
    begin
      dd "folder not found; creating..."
      dest.create(dest_folder)
      dest.select(dest_folder)
    rescue => ee
      dd "error: could not create folder: #{e}"
      next
    end
  end
  
  # Build a lookup hash of all message ids present in the destination folder.
  dest_info = {}
  
  dd 'analyzing existing messages...'
  uids = dest.uid_search(['ALL'])
  if uids.length > 0
    dest.uid_fetch(uids, ['ENVELOPE']).each do |data|
      dest_info[data.attr['ENVELOPE'].message_id] = true
    end
  end
  
  # Loop through all messages in the source folder.
  uids = source.uid_search(['ALL'])
  if uids.length > 0
    source.uid_fetch(uids, ['ENVELOPE']).each do |data|
      mid = data.attr['ENVELOPE'].message_id

      # If this message is already in the destination folder, skip it.
      next if dest_info[mid]
    
      # Download the full message body from the source folder.
      ds "downloading message #{mid}..."
      msg = source.uid_fetch(data.attr['UID'], ['RFC822', 'FLAGS',
          'INTERNALDATE']).first
    
      # Append the message to the destination folder, preserving flags and
      # internal timestamp.
      dd "storing message #{mid}..."
      dest.append(dest_folder, msg.attr['RFC822'], msg.attr['FLAGS'],
          msg.attr['INTERNALDATE'])
    end
  end
  
  source.close
  dest.close
end

puts 'done'