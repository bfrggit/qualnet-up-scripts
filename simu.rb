# Author: Charles ZHU
#
require "fileutils"
require "open3"

if ARGV.size != 1
	STDERR.puts "Usage: ruby simu.rb PLAN.plan"
	puts
	exit
end
planFileName = File.expand_path(ARGV[0])

planFileExt = /^.*\.plan$/
if not planFileExt.match planFileName
	STDERR.puts "Invalid plan file extension"
	puts
	exit
end

MY_NAME = "simu.rb"
SCENARIO_NAME = "up"

SIMULATION_WAIT_AFTER_END = 90

NODES_PER_NETWORK_MAXIMUM = 240

# Open configuration file
configFileName = SCENARIO_NAME + ".deployment"
text = nil
begin
	text = File.open(configFileName).read
rescue
	STDERR.puts "Cannot open configuration: " + configFileName
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
	return nil if arrMDC.size != 2
	return nil if not arrMDC[0].integer?
	speed = Integer(arrMDC[0])
	return nil if speed <= 0
	return nil if not arrMDC[1].numeric?
	bandwidth = Float(arrMDC[1])
	return nil if bandwidth <= 0
	return [speed, bandwidth]
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
	return nil if not arrDS[1].integer?
	chunk = Integer(arrDS[1])
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
elsif listAP.size > NODES_PER_NETWORK_MAXIMUM
	STDERR.puts "Too many access points"
	numErrors += 1
else puts "Parsed #{listAP.size} access point(s)"
end
if listDS.size < 1
	STDERR.puts "No data site"
	numErrors += 1
elsif listDS.size > NODES_PER_NETWORK_MAXIMUM
	STDERR.puts "Too many data sites"
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

listAP.sort! {|x, y| x[0] <=> y[0]}
listDS.sort! {|x, y| x[0] <=> y[0]}

# scenarioPartAppFileName = File.expand_path "#{SCENARIO_NAME}.part.app"
# scenarioPartConfigFileName = File.expand_path "#{SCENARIO_NAME}.part.config"
# scenarioPartNodesFileName = File.expand_path "#{SCENARIO_NAME}.part.nodes"
# scenarioAppFileName = File.expand_path "#{SCENARIO_NAME}.app"
# scenarioConfigFileName = File.expand_path "#{SCENARIO_NAME}.config"
# scenarioNodesFileName = File.expand_path "#{SCENARIO_NAME}.nodes"

scenarioPartAppFileName = "#{SCENARIO_NAME}.part.app"
scenarioPartConfigFileName = "#{SCENARIO_NAME}.part.config"
scenarioPartNodesFileName = "#{SCENARIO_NAME}.part.nodes"
scenarioAppFileName = "#{SCENARIO_NAME}.app"
scenarioConfigFileName = "#{SCENARIO_NAME}.config"
scenarioNodesFileName = "#{SCENARIO_NAME}.nodes"
scenarioRunScriptName = "run.sh"

# Open scenario configuration file
text = nil
begin
	text = File.open(scenarioPartConfigFileName).read
rescue
	STDERR.puts "Cannot open configuration: " + scenarioPartConfigFileName
	puts
	exit
end

# Read lines from scenario configuration file
lines = []
text.gsub!(/\r\n?/, "\n")
lineNum = 1
text.each_line do |line|
	lines << [line.strip, lineNum]
	lineNum += 1
end

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
puts "Read #{linesNoEmpty.size} line(s) from configuration: " \
	+ scenarioPartConfigFileName
puts

numErrors = 0
regServer = /^\[(\d+)\]\sHOSTNAME\s(server|mdc)\d+$/
nodeServerStr = nil
nodeMDCStr = nil
for line in linesNoEmpty
	match = regServer.match line[0]
	if match
		if match[2] == "server"
			puts "Found server, nodeId=#{match[1]}"
			if nodeServerStr
				STDERR.puts "Too many servers"
				numErrors += 1
			end
			nodeServerStr = match[1]
		elsif match[2] == "mdc"
			puts "Found mobile data collector, nodeId=#{match[1]}"
			if nodeMDCStr
				STDERR.puts "Too many mobile data collectors"
				numErrors += 1
			end
			nodeMDCStr = match[1]
		end
	end
end
if not nodeServerStr
	STDERR.puts "No server"
	numErrors += 1
end
if not nodeMDCStr
	STDERR.puts "No mobile data collector"
	numErrors += 1
end
puts

if numErrors > 0
	STDERR.puts "Found #{numErrors} error(s)"
	puts
	exit
end
puts "Found #{numErrors} error(s)"
puts

# Copy application specification
puts "Copying to file: " + scenarioAppFileName
FileUtils.cp scenarioPartAppFileName, scenarioAppFileName

puts "Writing to file: " + scenarioAppFileName
scenarioAppFileObj = File.open(scenarioAppFileName, "a")
scenarioAppFileObj.puts \
	"UP MDC #{nodeMDCStr} #{nodeServerStr} #{planFileName}"
scenarioAppFileObj.puts
scenarioAppFileObj.close
puts

ROLE_MDC = 1
ROLE_AP = 2
ROLE_DS = 3
ROLE_ROUTER = 4
ROLE_SWITCH = 5
ROLE_SERVER = 6
ROLES_HOSTNAME_STR = { \
	ROLE_MDC => "mdc%d", \
	ROLE_AP => "ap%d", \
	ROLE_DS => "data%d", \
	ROLE_SWITCH => "switch%d", \
	ROLE_ROUTER => "router%d", \
	ROLE_SERVER => "server%d"
}
ROLES_OUTPUT_STR = { \
	ROLE_MDC => "MDC", \
	ROLE_AP => "AP", \
	ROLE_DS => "DATA", \
	ROLE_SERVER => "CLOUD"
}
ROLES_OUTPUT_REVERSE_STR = { \
	"MDC" => ROLE_MDC, \
	"AP" => ROLE_AP, \
	"DATA" => ROLE_DS, \
	"CLOUD" => ROLE_SERVER
}

# Collect information of stop(s)
events = []
for j in 0...listAP.size
	itemAP = listAP[j]
	events << [itemAP[0], ROLE_AP, j + 1]
end
for j in 0...listDS.size
	itemDS = listDS[j]
	events << [itemDS[0], ROLE_DS, j + 1]
end
events.sort! {|x, y| x[0] <=> y[0]}

stops = []
for j in 0...events.size
	event = events[j]
	if stops.size < 1 or stops[-1][0] < event[0]
		stops << [event[0], []]
	end
	stops[-1][1] << [event[1], event[2]]
end
# stops.sort! {|x, y| x[0] <=> y[0]}

puts "Found #{stops.size} stop(s)"
puts

# Copy node placement configuration
puts "Copying to file: " + scenarioNodesFileName
FileUtils.cp scenarioPartNodesFileName, scenarioNodesFileName
puts

class String
	def numeric?
		Float(self) != nil rescue false
	end

	def integer?
		Integer(self) != nil rescue false
	end
end

outputFileName = "daemon_%s.out" % (ROLES_HOSTNAME_STR[ROLE_MDC] % nodeMDCStr)

R1 = ROLES_OUTPUT_STR[ROLE_MDC]
r2 = ROLES_HOSTNAME_STR[ROLE_MDC] % nodeMDCStr
R3 = ROLES_OUTPUT_STR[ROLE_AP]
R4 = ROLES_OUTPUT_STR[ROLE_DS]

regMDC = /^#{nodeMDCStr}\s([\d\.]+)S?\s\(([\d\.]*),\s?([\d\.]*),.*\)/
regOutput = /^#{R1}\s#{r2}\sCOMP\s(#{R3}|#{R4})\s(\d+)\sAT\sTIME\s([\d\.]+)$/
speedMDC = itemMDC[0]
for stopInd in 0...stops.size
	stop = stops[stopInd]
	puts "For stop #{stopInd + 1} at #{stop[0]}:"

	# Open node placement configuration
	text = nil
	begin
		text = File.open(scenarioNodesFileName).read
	rescue
		STDERR.puts "Cannot open configuration: " + scenarioNodesFileName
		puts
		exit
	end

	# Read lines from node placement configuration
	lines = []
	text.gsub!(/\r\n?/, "\n")
	lineNum = 1
	text.each_line do |line|
		lines << [line.strip, lineNum]
		lineNum += 1
	end

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
	# puts "Read #{linesNoEmpty.size} line(s) from configuration: " \
	# 	+ scenarioPartConfigFileName
	# puts

	zeroX = nil
	zeroY = nil
	lastT = -1.0/0.0
	lastX = nil
	for line in linesNoEmpty
		match = regMDC.match line[0]
		if match
			if match[1].numeric? and match[2].numeric? and match[3].numeric?
				if Float(match[1]) == 0
					zeroX = Float(match[2])
					zeroY = Float(match[3])
				end
				if Float(match[1]) > lastT
					lastT = Float(match[1])
					lastX = Float(match[2])
				end
			end
		end
	end
	lastX -= zeroX
	nextT = nil
	nextX = nil
	if stopInd < 1 # Make to first stop
		puts "Last stop: %.0f at time %.2f" % [lastX, lastT]
		distX = stop[0] - lastX
		nextT = lastT + distX * 1.0 / speedMDC
		nextX = Float(stop[0])
		puts "Next stop: %.0f at time %.2f" % [nextX, nextT]
	else # Make to next stop
		lastStop = stops[stopInd - 1]

		# Open output file
		outputText = nil
		begin
			outputText = File.open(outputFileName).read
		rescue
			STDERR.puts "Cannot open configuration: " + outputFileName
			puts
			exit
		end

		# Read lines from output file
		lines = []
		outputText.gsub!(/\r\n?/, "\n")
		lineNum = 1
		outputText.each_line do |line|
			lines << [line.strip, lineNum]
			lineNum += 1
		end

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

		lastTFromOutput = lastT
		for line in linesNoEmpty
			match = regOutput.match line[0]
			if match and match[2].integer? and match[3].numeric?
				siteType = ROLES_OUTPUT_REVERSE_STR[match[1]]
				next if not siteType
				siteId = Integer(match[2])
				siteTime = Float(match[3])
				if lastStop[1].include? [siteType, siteId]
					# p [siteType, siteId]
					if lastTFromOutput < siteTime
						lastTFromOutput = siteTime
					end
				end
			end
		end
		puts "Last stop: %.0f at time %.2f" % [lastX, lastTFromOutput]

		if lastTFromOutput > lastT
			# Append to node placement configuration
			puts "Writing to file: " + scenarioNodesFileName
			scenarioNodesFileObj = File.open(scenarioNodesFileName, "a")
			scenarioNodesFileObj.puts "%s %.2fS (%.4f, %.4f, %.4f) 0 0" \
				% [nodeMDCStr, lastTFromOutput, lastX + zeroX, zeroY, 0.0]
			scenarioNodesFileObj.close
		end

		distX = stop[0] - lastX
		nextT = lastTFromOutput + distX * 1.0 / speedMDC
		nextX = Float(stop[0])
		puts "Next stop: %.0f at time %.2f" % [nextX, nextT]
	end

	# Append to node placement configuration
	puts "Writing to file: " + scenarioNodesFileName
	scenarioNodesFileObj = File.open(scenarioNodesFileName, "a")
	scenarioNodesFileObj.puts "%s %.2fS (%.4f, %.4f, %.4f) 0 0" \
		% [nodeMDCStr, nextT, nextX + zeroX, zeroY, 0.0]
	scenarioNodesFileObj.close

	# Copy scenario configuration
	puts "Copying to file: " + scenarioConfigFileName
	FileUtils.cp scenarioPartConfigFileName, scenarioConfigFileName

	puts "Writing to file: " + scenarioConfigFileName
	scenarioConfigFileObj = File.open(scenarioConfigFileName, "a")
	scenarioConfigFileObj.puts "# Generated by #{MY_NAME}"
	scenarioConfigFileObj.puts "
SIMULATION-TIME %dS" % (nextT + SIMULATION_WAIT_AFTER_END).ceil
	scenarioConfigFileObj.puts
	scenarioConfigFileObj.close
	puts
	command = "./#{scenarioRunScriptName}"
	simulation = Open3.popen3 command
	errLines = simulation[2].readlines
	if errLines.size > 0
		puts "Error occurred in simulation:"
		puts errLines
		puts
	end
end


#
#puts
