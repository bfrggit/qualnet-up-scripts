# Author: Charles ZHU
#
if ARGV.size != 2
	STDERR.puts "Usage: ruby make_scenario.rb CONFIG.up.config DIRECTORY"
	puts
	exit
end
configFileName = File.expand_path(ARGV[0])
scenarioDirName = File.expand_path(ARGV[1])

MY_NAME = "make_scenario.rb"
SCENARIO_NAME = "up"

TERRAIN_MARGIN = 100
TERRAIN_WIDTH = 1000
TERRAIN_LENGTH_MINIMUM = 500

IP_WIRELESS_SUBNET_SIMU_NET = "190.46.1.%d"
IP_WIRELESS_SUBNET_MDC_NET = "190.47.1.%d"
IP_WIRED_SUBNET = "190.48.0.%d"
IP_LINK = "190.40.%d.%d"

NETWORK_NODES_MAXIMUM = 240
MDC_HOST_ID = 251
ROUTER_HOST_ID = 254
SERVER_HOST_ID = 253

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
	if not File.directory? scenarioDirName
		Dir.mkdir scenarioDirName
		puts "Made directory: " + scenarioDirName
	end
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
elsif listAP.size > NETWORK_NODES_MAXIMUM
	STDERR.puts "Too many access points"
	numErrors += 1
else puts "Parsed #{listAP.size} access point(s)"
end
if listDS.size < 1
	STDERR.puts "No data site"
	numErrors += 1
elsif listDS.size > NETWORK_NODES_MAXIMUM
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

# Calculate terrain dimensions\
puts "Generated terrain dimensions:"
puts "Margin: #{TERRAIN_MARGIN}"
puts "Width: #{TERRAIN_WIDTH}"
terrainLength = [TERRAIN_LENGTH_MINIMUM, listAP[-1][0], listDS[-1][0]].max
puts "Length: #{terrainLength}"
puts

# Assign roles to nodes
ROLE_MDC = 1
ROLE_AP = 2
ROLE_DS = 3
ROLE_ROUTER = 4
ROLE_SERVER = 5
ROLES_STR = { \
	ROLE_MDC => "Mobile data collector", \
	ROLE_AP => "Access point", \
	ROLE_DS => "Data site", \
	ROLE_ROUTER => "Router", \
	ROLE_SERVER => "Cloud server"
}

nodeNum = 0
nodes = []

nodeNum += 1
itemRouter = []
itemRouter << nodeNum
itemRouter << ROUTER_HOST_ID
nodes << [nodeNum, ROLE_ROUTER, nil]
nodeNum += 1
itemServer = []
itemServer << nodeNum
itemServer << SERVER_HOST_ID
nodes << [nodeNum, ROLE_SERVER, nil]
nodeNum += 1
itemMDC << nodeNum
itemMDC << MDC_HOST_ID
nodes << [nodeNum, ROLE_MDC, nil]
for j in 0...listAP.size
	nodeNum += 1
	listAP[j] << nodeNum
	listAP[j] << 4 + j
	nodes << [nodeNum, ROLE_AP, j]
end
for j in 0...listDS.size
	nodeNum += 1
	listDS[j] << nodeNum
	listDS[j] << 4 + j
	nodes << [nodeNum, ROLE_DS, j]
end

puts "Assigned roles to nodes:"
for j in 0...nodes.size
	print "[%d] %s, " % [nodes[j][0], ROLES_STR[nodes[j][1]]]
	if nodes[j][1] == ROLE_MDC
		print IP_WIRELESS_SUBNET_SIMU_NET % itemMDC[-1] + ", "
		print IP_WIRELESS_SUBNET_MDC_NET % itemMDC[-1]
	elsif nodes[j][1] == ROLE_AP
		print IP_WIRELESS_SUBNET_SIMU_NET % listAP[nodes[j][2]][-1]
	elsif nodes[j][1] == ROLE_DS
		print IP_WIRELESS_SUBNET_MDC_NET % listDS[nodes[j][2]][-1]
	elsif nodes[j][1] == ROLE_ROUTER
		print IP_WIRELESS_SUBNET_SIMU_NET % itemRouter[-1] + ", "
		print IP_WIRED_SUBNET % itemRouter[-1]
	elsif nodes[j][1] == ROLE_SERVER
		print IP_WIRED_SUBNET % itemServer[-1]
	end
	puts
end
puts

puts "Writing scenario files to directory: " + scenarioDirName
scenarioAppFileName = scenarioDirName + "/#{SCENARIO_NAME}.app"
scenarioConfigFileName = scenarioDirName + "/#{SCENARIO_NAME}.config"
scenarioDisplayFileName = scenarioDirName + "/#{SCENARIO_NAME}.display"
scenarioNodesFileName = scenarioDirName + "/#{SCENARIO_NAME}.nodes"

# TODO: Generate application specification
puts "Writing to file: " + scenarioAppFileName

# TODO: Generate scenario configuration
puts "Writing to file: " + scenarioConfigFileName
scenarioConfigFileObj = File.open(scenarioConfigFileName, "w")
scenarioConfigFileObj.puts "# QualNet Configuration File"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# Generated by #{MY_NAME}"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# General Settings"
scenarioConfigFileObj.puts "
VERSION 12.10
EXPERIMENT-NAME up
EXPERIMENT-COMMENT NONE
SIMULATION-TIME 60S
SEED 1
MULTI-GUI-INTERFACE NO
GUI-CONFIG-LOCKED NO"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# Parallel Settings"
scenarioConfigFileObj.puts "
PARTITION-SCHEME AUTO
GESTALT-PREFER-SHARED-MEMORY YES"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# Advanced Settings"
scenarioConfigFileObj.puts "
DYNAMIC-ENABLED NO"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# Terrain"
scenarioConfigFileObj.puts "
COORDINATE-SYSTEM CARTESIAN
TERRAIN-DIMENSIONS (%d, %d)
WEATHER-MOBILITY-INTERVAL 10S" \
% [TERRAIN_WIDTH + 2 * TERRAIN_MARGIN, terrainLength + 2 * TERRAIN_MARGIN]
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# Channel Properties"
scenarioConfigFileObj.puts "
PROPAGATION-CHANNEL-NAME[0] channel0
PROPAGATION-CHANNEL-FREQUENCY[0] 2400000000
PROPAGATION-MODEL[0] STATISTICAL
PROPAGATION-PATHLOSS-MODEL[0] TWO-RAY
PROPAGATION-SHADOWING-MODEL[0] CONSTANT
PROPAGATION-SHADOWING-MEAN[0] 4.0
PROPAGATION-FADING-MODEL[0] NONE
PROPAGATION-ENABLE-CHANNEL-OVERLAP-CHECK[0] NO
PROPAGATION-SPEED[0] 3e8
PROPAGATION-LIMIT[0] -111.0
PROPAGATION-MAX-DISTANCE[0] 0
PROPAGATION-COMMUNICATION-PROXIMITY[0] 400
PROPAGATION-PROFILE-UPDATE-RATIO[0] 0.0"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# Mobility and Placement"
scenarioConfigFileObj.puts "
NODE-PLACEMENT FILE
MOBILITY NONE"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# Statistics"
scenarioConfigFileObj.puts "
PHY-LAYER-STATISTICS YES
MAC-LAYER-STATISTICS YES
ACCESS-LIST-STATISTICS NO
ARP-STATISTICS NO
ROUTING-STATISTICS YES
POLICY-ROUTING-STATISTICS NO
QOSPF-STATISTICS NO
ROUTE-REDISTRIBUTION-STATISTICS NO
EXTERIOR-GATEWAY-PROTOCOL-STATISTICS YES
MULTICAST-MSDP-STATISTICS NO
NETWORK-LAYER-STATISTICS YES
INPUT-QUEUE-STATISTICS NO
INPUT-SCHEDULER-STATISTICS NO
QUEUE-STATISTICS YES
SCHEDULER-STATISTICS NO
SCHEDULER-GRAPH-STATISTICS NO
DIFFSERV-EDGE-ROUTER-STATISTICS NO
ICMP-STATISTICS NO
ICMP-ERROR-STATISTICS NO
IGMP-STATISTICS NO
NDP-STATISTICS NO
MOBILE-IP-STATISTICS NO
TCP-STATISTICS YES
UDP-STATISTICS YES
MDP-STATISTICS NO
RSVP-STATISTICS NO
RTP-STATISTICS NO
APPLICATION-STATISTICS YES
BATTERY-MODEL-STATISTICS NO
ENERGY-MODEL-STATISTICS YES
VOIP-SIGNALLING-STATISTICS NO
SWITCH-PORT-STATISTICS NO
SWITCH-SCHEDULER-STATISTICS NO
SWITCH-QUEUE-STATISTICS NO
MPLS-STATISTICS NO
MPLS-LDP-STATISTICS NO
HOST-STATISTICS NO
DHCP-STATISTICS NO
DNS-STATISTICS NO"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# Packet Tracing"
scenarioConfigFileObj.puts "
PACKET-TRACE NO
ACCESS-LIST-TRACE NO"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# Miscellaneous Settings"
scenarioConfigFileObj.puts "
STATS-DB-COLLECTION NO
AGI-INTERFACE NO
SOCKET-INTERFACE NO
VRLINK NO
DIS NO
HLA NO"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# Physical Layer"
scenarioConfigFileObj.puts "
PHY-LISTENABLE-CHANNELS channel0
PHY-LISTENING-CHANNELS channel0
PHY-MODEL PHY802.11b
PHY802.11-AUTO-RATE-FALLBACK NO
PHY802.11-DATA-RATE 2000000
PHY802.11b-TX-POWER--1MBPS 15.0
PHY802.11b-TX-POWER--2MBPS 15.0
PHY802.11b-TX-POWER--6MBPS 15.0
PHY802.11b-TX-POWER-11MBPS 15.0
PHY802.11b-RX-SENSITIVITY--1MBPS -94.0
PHY802.11b-RX-SENSITIVITY--2MBPS -91.0
PHY802.11b-RX-SENSITIVITY--6MBPS -87.0
PHY802.11b-RX-SENSITIVITY-11MBPS -83.0
PHY802.11-ESTIMATED-DIRECTIONAL-ANTENNA-GAIN 15.0
PHY-RX-MODEL PHY802.11b
DUMMY-ANTENNA-MODEL-CONFIG-FILE-SPECIFY NO
ANTENNA-MODEL OMNIDIRECTIONAL
ANTENNA-GAIN 0.0
ANTENNA-HEIGHT 1.5
ANTENNA-EFFICIENCY 0.8
ANTENNA-MISMATCH-LOSS 0.3
ANTENNA-CABLE-LOSS 0.0
ANTENNA-CONNECTION-LOSS 0.2
ANTENNA-ORIENTATION-AZIMUTH 0
ANTENNA-ORIENTATION-ELEVATION 0
PHY-TEMPERATURE 290.0
PHY-NOISE-FACTOR 10.0
ENERGY-MODEL-SPECIFICATION NONE"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# MAC Layer"
scenarioConfigFileObj.puts "
LINK-MAC-PROTOCOL ABSTRACT
LINK-PROPAGATION-DELAY 1MS
LINK-BANDWIDTH 10000000
LINK-HEADER-SIZE-IN-BITS 224
LINK-TX-FREQUENCY 13170000000
LINK-RX-FREQUENCY 13170000000
LINK-TX-ANTENNA-HEIGHT 30
LINK-RX-ANTENNA-HEIGHT 30
LINK-TX-ANTENNA-DISH-DIAMETER 0.8
LINK-RX-ANTENNA-DISH-DIAMETER 0.8
LINK-TX-ANTENNA-CABLE-LOSS 1.5
LINK-RX-ANTENNA-CABLE-LOSS 1.5
LINK-TX-POWER 30
LINK-RX-SENSITIVITY -80
LINK-NOISE-TEMPERATURE 290
LINK-NOISE-FACTOR 4
LINK-TERRAIN-TYPE PLAINS
LINK-PROPAGATION-RAIN-INTENSITY 0
LINK-PROPAGATION-TEMPERATURE 25
LINK-PROPAGATION-SAMPLING-DISTANCE 100
LINK-PROPAGATION-CLIMATE 1
LINK-PROPAGATION-REFRACTIVITY 360
LINK-PROPAGATION-PERMITTIVITY 15
LINK-PROPAGATION-CONDUCTIVITY 0.005
LINK-PROPAGATION-HUMIDITY 50
LINK-PERCENTAGE-TIME-REFRACTIVITY-GRADIENT-LESS-STANDARD 15
MAC-PROTOCOL MACDOT11
MAC-DOT11-SHORT-PACKET-TRANSMIT-LIMIT 7
MAC-DOT11-LONG-PACKET-TRANSMIT-LIMIT 4
MAC-DOT11-RTS-THRESHOLD 0
MAC-DOT11-STOP-RECEIVING-AFTER-HEADER-MODE NO
MAC-DOT11-ASSOCIATION NONE
MAC-DOT11-IBSS-SUPPORT-PS-MODE NO
MAC-DOT11-DIRECTIONAL-ANTENNA-MODE NO
MAC-PROPAGATION-DELAY 1US"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# Miscellaneous Settings"
scenarioConfigFileObj.puts "
IP-QUEUE-PRIORITY-INPUT-QUEUE-SIZE 150000
IP-QUEUE-SCHEDULER STRICT-PRIORITY
IP-QUEUE-NUM-PRIORITIES 3

FIXED-COMMS-DROP-PROBABILITY 0.0

BGP-ENABLE-ROUTER-ID NO
BGP-ENABLE-ROUTER-ID_IPv6 YES
BGP ROUTER-ID 127.0.0.1

DUMMY-ROUTER-TYPE USER-SPECIFIED"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# Network Layer"
scenarioConfigFileObj.puts "
NETWORK-PROTOCOL IP
IP-ENABLE-LOOPBACK YES
IP-LOOPBACK-ADDRESS 127.0.0.1
IP-FRAGMENT-HOLD-TIME 60S
IP-FRAGMENTATION-UNIT 2048
ECN NO
ICMP YES
ICMP-ROUTER-ADVERTISEMENT-LIFE-TIME 1800S
ICMP-ROUTER-ADVERTISEMENT-MIN-INTERVAL 450S
ICMP-ROUTER-ADVERTISEMENT-MAX-INTERVAL 600S
ICMP-MAX-NUM-SOLICITATION 3
MOBILE-IP NO"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# Routing Protocol"
scenarioConfigFileObj.puts "
ROUTING-PROTOCOL BELLMANFORD
STATIC-ROUTE NO
DEFAULT-ROUTE NO
DUMMY-MULTICAST NO"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# Transport Layer"
scenarioConfigFileObj.puts "
TRANSPORT-PROTOCOL-RSVP YES
GUI_DUMMY_CONFIG_TCP YES
TCP LITE
TCP-USE-RFC1323 NO
TCP-DELAY-SHORT-PACKETS-ACKS NO
TCP-USE-NAGLE-ALGORITHM YES
TCP-USE-KEEPALIVE-PROBES YES
TCP-USE-OPTIONS YES
TCP-DELAY-ACKS YES
TCP-MSS 512
TCP-SEND-BUFFER 16384
TCP-RECEIVE-BUFFER 16384"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# MPLS Specs"
scenarioConfigFileObj.puts "
MPLS-PROTOCOL NO"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# Application Layer"
scenarioConfigFileObj.puts "
RTP-ENABLED NO
MDP-ENABLED NO"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# Battery Models"
scenarioConfigFileObj.puts "
BATTERY-MODEL NONE"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# Adaptation Protocol"
scenarioConfigFileObj.puts "
ADAPTATION-PROTOCOL AAL5
ATM-CONNECTION-REFRESH-TIME 5M
ATM-CONNECTION-TIMEOUT-TIME 1M
IP-QUEUE-PRIORITY-QUEUE-SIZE 150000
IP-QUEUE-TYPE FIFO"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# Miscellaneous Settings"
scenarioConfigFileObj.puts "
GUI-DISPLAY-SETTINGS-FILE #{SCENARIO_NAME}.display
APP-CONFIG-FILE #{SCENARIO_NAME}.app"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# [Default Wireless Subnet]"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# [Wireless Subnet] Access Points"
scenarioConfigFileObj.puts "
"


scenarioConfigFileObj.close

# TODO: Generate display configuration
puts "Writing to file: " + scenarioDisplayFileName

# TODO: Generate node placement configuration
puts "Writing to file: " + scenarioNodesFileName
puts
