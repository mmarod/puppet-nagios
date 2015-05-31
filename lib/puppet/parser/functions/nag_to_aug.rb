# Converts an array of cfg_file or cfg_dir keys into a format
# that the augeas type can understand.
#
# @example Standard usage
#   # Input
#   nag_to_aug([ '/etc/nagios/commands.cfg', '/etc/nagios/anotherconfig.cfg' ], 'cfg_file', '/etc/nagios3/nagios.cfg')
#
#   # Returns
#   { 'changes' => [ "rm cfg_file",
#                    "ins cfg_file before /files/etc/nagios3/nagios.cfg/#comment[.]'LOG FILE']",
#                    "set cfg_file[1] /etc/nagios/commands.cfg",
#                    "ins cfg_file after /files/etc/nagios3/nagios.cfg/cfg_file[last()]",
#                    "set cfg_file[2] /etc/nagios/anotherconfig.cfg" ],
#     'onlyif'  => "values cfg_file != ['/etc/nagios/commands.cfg', '/etc/nagios/anotherconfig.cfg']"
#   }
#
module Puppet::Parser::Functions
  newfunction(:nag_to_aug, :type => :rvalue) do |args|
    values = args[0]
    type = args[1]
    filename = args[2]

    path = "/files#{filename}/#{type}"
    comment_path = "/files#{filename}/#comment"
    onlyif  = []

    match = "['" + values.join("', '") + "']"
    onlyif = "values #{type} != #{match}"

    first = values.shift
    changes = []
    changes.push("rm #{type}")
    changes.push("ins #{type} before #{comment_path}[.='LOG FILE']") 
    changes.push("set #{type}[1] #{first}")

    values.each do |val|
      changes.push("ins #{type} after #{path}[last()]")
      changes.push("set #{type}[last()] #{val}")
    end

    return { "changes" => changes, "onlyif" => onlyif }
  end
end
