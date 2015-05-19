module Puppet::Parser::Functions
  newfunction(:nag_to_aug, :type => :rvalue) do |args|
    values = args[0]
    type = args[1]
    filename = args[2]

    path = "/files#{filename}/#{type}"
    comment_path = "/files#{filename}/#comment"
    onlyif  = []

    match = "['" + values.join("', '") + "']"
    onlyif = "match #{type} != #{match}"

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
