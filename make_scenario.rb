if ARGV.size != 2
	STDERR.puts "Usage: ruby make_scenario.rb CONFIG.up.config DIRECTORY"
	puts
	exit
end
configFileName = ARGV[0]
scenarioDirInput = ARGV[1]
scenarioDirName = File.expand_path(scenarioDirInput)

configFileExt = /^.*\.up\.config$/
if not configFileExt.match configFileName
	STDERR.puts "Invalid configuration file extension"
	puts
	exit
end

# Open configuration file
text = nil
begin
	text = File.open(configFileName).read
rescue
	STDERR.puts "Cannot open configuration: " + configFileName
	puts
	exit
end

# Make directory
begin
	Dir.mkdir scenarioDirName if not File.directory? scenarioDirName
rescue
	STDERR.puts "Cannot create scenario directory: " + scenarioDirName
	puts
	exit
end

# Check directory, should be empty
scenarioDirContents = nil
begin
	scenarioDirContents = Dir.entries scenarioDirName
rescue
	STDERR.puts "Cannot access scenario directory: " + scenarioDirName
	puts
	exit
end
scenarioDirContents.delete_if {|filename| filename == "." or filename == ".."}
if scenarioDirContents.size > 0
	STDERR.puts "Found a dirty scenario directory: " + scenarioDirName
	puts
	exit
end

# Read lines from configuration file
lines = []
text.gsub!(/\r\n?/, "\n")
lineNum = 1
text.each_line do |line|
	lines << [line.strip, lineNum]
	lineNum += 1
end
# puts "Read #{lines.size} line(s) from configuration: " + configFileName

# if lines.size < 1
# 	STDERR.puts "Empty configuration: " + configFileName
# 	puts
# 	exit
# end

linesNoEmpty = []
for j in 0...lines.size
	line, lineNum = lines[j]
	parts = line.split("#")
	next if parts.size < 1
	info = parts[0].strip
	if info.size > 0
		linesNoEmpty << [info, lineNum]
	end
end
lines = nil
puts "Read #{linesNoEmpty.size} line(s) from configuration: " + configFileName

if linesNoEmpty.size < 1
	STDERR.puts "Empty configuration: " + configFileName
	puts
	exit
end
puts

# Parse configuration file
SECTION_UNCHANGED = -1
SECTION_NONE = 0
SECTION_MDC = 1
SECTION_AP = 2
SECTION_DATA = 3

def getSectionChange(line)
	if line == "MOBILE_DATA_COLLECTOR"
		return SECTION_MDC
	elsif line == "ACCESS_POINTS"
		return SECTION_AP
	elsif line == "DATA_SITES"
		return SECTION_DATA
	else
		return SECTION_UNCHANGED
	end
end

class String
	def numeric?
		Float(self) != nil rescue false
	end

	def integer?
		Integer(self) != nil rescue false
	end
end

def parseLineMDC(line)
	arrMDC = line.split
	return nil if arrMDC.size != 1
	return nil if not arrMDC[0].integer?
	speed = Integer(arrMDC[0])
	return nil if speed <= 0
	return [speed]
end

def parseLineAP(line)
	arrAP = line.split
	return nil if arrAP.size != 2
	return nil if not arrAP[0].integer?
	position = Integer(arrAP[0])
	return nil if position < 0
	return nil if not arrAP[1].numeric?
	bandwidth = Float(arrAP[1])
	return nil if bandwidth <= 0
	return [position, bandwidth]
end

def parseLineDS(line)
	arrDS = line.split
	return nil if arrDS.size != 4
	return nil if not arrDS[0].integer?
	position = Integer(arrDS[0])
	return nil if position < 0
	return nil if not arrDS[1].numeric?
	chunk = Float(arrDS[1])
	return nil if chunk <= 0
	return nil if not arrDS[2].integer?
	deadline = Integer(arrDS[2])
	return nil if deadline <= 0
	return nil if not arrDS[3].numeric?
	priority = Float(arrDS[3])
	return nil if priority <= 0 or priority > 1
	return [position, chunk, deadline, priority]
end

section = SECTION_NONE
listAP = []
listDS = []
itemMDC = nil
numErrors = 0
for j in 0...linesNoEmpty.size
	line, lineNum = linesNoEmpty[j]
	sectionChange = getSectionChange(line)
	if sectionChange != SECTION_UNCHANGED and sectionChange != SECTION_NONE
		section = sectionChange
		next
	end
		
	if section == SECTION_NONE
		puts "Invalid line under no section: #{lineNum}"
	elsif section == SECTION_MDC
		itemMDC = parseLineMDC(line)
		if not itemMDC
			STDERR.puts "Line #{lineNum}: Invalid mobile data collector"
			numErrors += 1
		end
		section = SECTION_NONE
	elsif section == SECTION_AP
		itemAP = parseLineAP(line)
		if not itemAP
			STDERR.puts "Line #{lineNum}: Invalid access point"
			numErrors += 1
		else
			listAP << itemAP
		end
	elsif section == SECTION_DATA
		itemDS = parseLineDS(line)
		if not itemDS
			STDERR.puts "Line #{lineNum}: Invalid data site"
			numErrors += 1
		else
			listDS << itemDS
		end
	end
end
if not itemMDC
	STDERR.puts "No mobile data collector"
	numErrors += 1
else puts "Parsed mobile data collector"
end
if listAP.size < 1
	STDERR.puts "No access point"
	numErrors += 1
else puts "Parsed #{listAP.size} access point(s)"
end
if listDS.size < 1
	STDERR.puts "No data site"
	numErrors += 1
else puts "Parsed #{listDS.size} data site(s)"
end
puts

if numErrors > 0
	STDERR.puts "Found #{numErrors} error(s)"
	puts
	exit
end
puts "Found #{numErrors} error(s)"
puts

# TODO: Generate scenario files
