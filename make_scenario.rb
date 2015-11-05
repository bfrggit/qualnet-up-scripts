# Author: Charles ZHU
#
require "fileutils"

if ARGV.size != 2
	STDERR.puts "Usage: ruby make_scenario.rb CONFIG.up.deployment DIRECTORY"
	puts
	exit
end
configFileName = File.expand_path(ARGV[0])
scenarioDirName = File.expand_path(ARGV[1])

configFileExt = /^.*\.up\.deployment$/
if not configFileExt.match configFileName
	STDERR.puts "Invalid configuration file extension"
	puts
	exit
end

MY_NAME = "make_scenario.rb"
SCENARIO_NAME = "up"

TERRAIN_MARGIN = 100
TERRAIN_WIDTH = 800
TERRAIN_LENGTH_MINIMUM = 800

MDC_WAIT_BEFORE_START = 30
SIMULATION_WAIT_AFTER_END = 90

NODE_NUMBER_ZERO = 100
NODES_PER_NETWORK_MAXIMUM = 240

PLACEMENT_X_WIRELESS_SUBNET_SIMU_NET = 200
PLACEMENT_X_WIRELESS_SUBNET_MDC_NET = 400
PLACEMENT_X_WIRED_SUBNET = 800
PLACEMENT_X_SWITCH = 600
PLACEMENT_X_ROUTER = (PLACEMENT_X_SWITCH + PLACEMENT_X_WIRED_SUBNET) / 2
PLACEMENT_X_SERVER = 800

PLACEMENT_Y_PATH = 0
PLACEMENT_Y_SUBNET = 400
PLACEMENT_Y_ROUTER = 600
PLACEMENT_Y_SERVER = 800

TX_POWER_AP = -10.0
TX_POWER_DS = -20.0
TX_POWER_MDC = -20.0

SSID_WIRELESS_SUBNET_SIMU_NET = "SimuNet"
SSID_WIRELESS_SUBNET_MDC_NET = "MDCNet"

MAC_ADDRESS_PREFIX = "51:80:00:46"
MAC_ADDRESS_OFFSET = 1

IP_WIRELESS_SUBNET_SIMU_NET = "190.46.%d.%d"
IP_WIRELESS_SUBNET_MDC_NET = "190.47.%d.%d"
IP_WIRED_SUBNET = "190.48.%d.%d"
IP_LINKS_SWITCH = "190.49.%d.%d"
IP_SUBNET_MASK_LENGTH = 16
MASK = IP_SUBNET_MASK_LENGTH

IP_HOST_ID_NETWORK = [0, 0]
IP_HOST_ID_MDC = [251, 251]
IP_HOST_ID_ROUTER = [251, 254]
IP_HOST_ID_SERVER = [251, 253]

IP_HOST_ID_BYTE_3_BEGIN = 11
IP_HOST_ID_BYTE_3_END = 210
IP_HOST_ID_BYTE_2_BEGIN = 11
IP_HOST_ID_BYTE_2_END = 110
IP_HOST_ID_BYTE_2_OFFSET = 100

PROPOGATION_DELAY_SERVER_ROUTER = 10

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
ROLE_SWITCH = 5
ROLE_SERVER = 6
ROLES_STR = { \
	ROLE_MDC => "Mobile data collector", \
	ROLE_AP => "Access point", \
	ROLE_DS => "Data site", \
	ROLE_ROUTER => "Router", \
	ROLE_SWITCH => "Switch", \
	ROLE_SERVER => "Cloud server"
}
ROLES_HOSTNAME_STR = { \
	ROLE_MDC => "mdc%d", \
	ROLE_AP => "ap%d", \
	ROLE_DS => "data%d", \
	ROLE_SWITCH => "switch%d", \
	ROLE_ROUTER => "router%d", \
	ROLE_SERVER => "server%d"
}

nodeNum = NODE_NUMBER_ZERO
nodes = []

nodeNum += 1
itemServer = []
itemServer << nodeNum
itemServer << IP_HOST_ID_SERVER
nodes << [nodeNum, ROLE_SERVER, nil]
nodeNum += 1
itemRouter = []
itemRouter << nodeNum
itemRouter << IP_HOST_ID_ROUTER
nodes << [nodeNum, ROLE_ROUTER, nil]
nodeNum += 1
itemSwitch = []
itemSwitch << nodeNum
itemSwitch << nil
nodes << [nodeNum, ROLE_SWITCH, nil]
nodeNum += 1
itemMDC << nodeNum
itemMDC << IP_HOST_ID_MDC
nodes << [nodeNum, ROLE_MDC, nil]

def convertItemIndexToHostId(index, offset=false)
	hostPerByte3 = IP_HOST_ID_BYTE_3_END - IP_HOST_ID_BYTE_3_BEGIN + 1
	hostPerByte2 = IP_HOST_ID_BYTE_2_END - IP_HOST_ID_BYTE_2_BEGIN + 1
	if index + 1 > hostPerByte3 * hostPerByte2
		raise ArgumentError
	end
	byte2 = (index.div hostPerByte3) + IP_HOST_ID_BYTE_2_BEGIN
	byte3 = index % hostPerByte3 + IP_HOST_ID_BYTE_3_BEGIN
	byte2 += IP_HOST_ID_BYTE_2_OFFSET if offset
	return [byte2, byte3]
end

for j in 0...listAP.size
	nodeNum += 1
	listAP[j] << nodeNum
	listAP[j] << convertItemIndexToHostId(j)
	nodes << [nodeNum, ROLE_AP, j]
end
for j in 0...listDS.size
	nodeNum += 1
	listDS[j] << nodeNum
	listDS[j] << convertItemIndexToHostId(j)
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
	elsif nodes[j][1] == ROLE_SWITCH
		print "-"
	elsif nodes[j][1] == ROLE_SERVER
		print IP_WIRED_SUBNET % itemServer[-1]
	end
	puts
end
puts

puts "Writing scenario files to directory: " + scenarioDirName
deploymentFileName = scenarioDirName + "/#{SCENARIO_NAME}.deployment"
scenarioAppFileName = scenarioDirName + "/#{SCENARIO_NAME}.app"
scenarioConfigFileName = scenarioDirName + "/#{SCENARIO_NAME}.part.config"
scenarioDisplayFileName = scenarioDirName + "/#{SCENARIO_NAME}.display"
scenarioHardwareAddressFileName = scenarioDirName \
	+ "/#{SCENARIO_NAME}.mac-address"
scenarioNodesFileName = scenarioDirName + "/#{SCENARIO_NAME}.part.nodes"
scenarioTestScriptName = scenarioDirName + "/test.sh"
scenarioTestAppFileName = scenarioDirName + "/#{SCENARIO_NAME}.test.app"
scenarioTestConfigFileName = scenarioDirName + "/#{SCENARIO_NAME}.test.config"
scenarioTestNodesFileName = scenarioDirName + "/#{SCENARIO_NAME}.test.nodes"

# Generate scenario configuration
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
% [terrainLength + 2 * TERRAIN_MARGIN, TERRAIN_WIDTH + 2 * TERRAIN_MARGIN]
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
PHY-MODEL PHY802.11a
PHY802.11-AUTO-RATE-FALLBACK NO
PHY802.11-DATA-RATE 48000000
PHY802.11a-TX-POWER--6MBPS 20.0
PHY802.11a-TX-POWER--9MBPS 20.0
PHY802.11a-TX-POWER-12MBPS 19.0
PHY802.11a-TX-POWER-18MBPS 19.0
PHY802.11a-TX-POWER-24MBPS 18.0
PHY802.11a-TX-POWER-36MBPS 18.0
PHY802.11a-TX-POWER-48MBPS 16.0
PHY802.11a-TX-POWER-54MBPS 16.0
PHY802.11a-RX-SENSITIVITY--6MBPS -85.0
PHY802.11a-RX-SENSITIVITY--9MBPS -85.0
PHY802.11a-RX-SENSITIVITY-12MBPS -83.0
PHY802.11a-RX-SENSITIVITY-18MBPS -83.0
PHY802.11a-RX-SENSITIVITY-24MBPS -78.0
PHY802.11a-RX-SENSITIVITY-36MBPS -78.0
PHY802.11a-RX-SENSITIVITY-48MBPS -69.0
PHY802.11a-RX-SENSITIVITY-54MBPS -69.0
PHY-RX-MODEL PHY802.11a
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
GUI-DISPLAY-SETTINGS-FILE #{SCENARIO_NAME}.display"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# [Default Wireless Subnet]"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# [Wireless Subnet] Access Points"
scenarioConfigFileObj.puts "
SUBNET N#{MASK}-%s {%d thru %d, %d} %d %d 0" \
	% [IP_WIRELESS_SUBNET_SIMU_NET % IP_HOST_ID_NETWORK, \
		listAP[0][-2], listAP[-1][-2], itemMDC[-2], \
		PLACEMENT_X_WIRELESS_SUBNET_SIMU_NET \
			+ TERRAIN_MARGIN, PLACEMENT_Y_SUBNET + TERRAIN_MARGIN]
scenarioConfigFileObj.puts "
[ N#{MASK}-%s ] PHY-MODEL PHY802.11a
[ N#{MASK}-%s ] PHY802.11-AUTO-RATE-FALLBACK NO
[ N#{MASK}-%s ] PHY802.11-DATA-RATE #{48 * 1000 * 1000}
[ N#{MASK}-%s ] PHY-RX-MODEL PHY802.11a
[ N#{MASK}-%s ] DUMMY-ANTENNA-MODEL-CONFIG-FILE-SPECIFY NO
[ N#{MASK}-%s ] ANTENNA-MODEL OMNIDIRECTIONAL
[ N#{MASK}-%s ] ENERGY-MODEL-SPECIFICATION NONE

[ N#{MASK}-%s ] MAC-PROTOCOL MACDOT11
[ N#{MASK}-%s ] MAC-DOT11-ASSOCIATION DYNAMIC
[ N#{MASK}-%s ] MAC-DOT11-SSID #{SSID_WIRELESS_SUBNET_SIMU_NET}
[ N#{MASK}-%s ] MAC-DOT11-AP NO
[ N#{MASK}-%s ] MAC-DOT11-SCAN-TYPE PASSIVE
[ N#{MASK}-%s ] DUMMY-MAC-DOT11-STATION-HANDOVER-RSS-TRIGGER YES
[ N#{MASK}-%s ] MAC-DOT11-STATION-HANDOVER-RSS-TRIGGER -87.0
[ N#{MASK}-%s ] MAC-DOT11-STA-PS-MODE-ENABLED NO
[ N#{MASK}-%s ] MAC-DOT11-DIRECTIONAL-ANTENNA-MODE NO
[ N#{MASK}-%s ] LLC-ENABLED YES

[ N#{MASK}-%s ] NETWORK-PROTOCOL IP

[ N#{MASK}-%s ] ARP-ENABLED YES
[ N#{MASK}-%s ] ARP-CACHE-EXPIRE-INTERVAL 20M" \
	% ([IP_WIRELESS_SUBNET_SIMU_NET % IP_HOST_ID_NETWORK] * 20)
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# [Wireless Subnet] Mobile Data Collector"
scenarioConfigFileObj.puts "
SUBNET N#{MASK}-%s {%d thru %d, %d} %d %d 0" \
	% [IP_WIRELESS_SUBNET_MDC_NET % IP_HOST_ID_NETWORK, \
		listDS[0][-2], listDS[-1][-2], itemMDC[-2], \
		PLACEMENT_X_WIRELESS_SUBNET_MDC_NET \
			+ TERRAIN_MARGIN, PLACEMENT_Y_SUBNET + TERRAIN_MARGIN]
scenarioConfigFileObj.puts "
[ N#{MASK}-%s ] PHY-MODEL PHY802.11a
[ N#{MASK}-%s ] PHY802.11-AUTO-RATE-FALLBACK NO
[ N#{MASK}-%s ] PHY802.11-DATA-RATE #{(itemMDC[1] * 1000).round}
[ N#{MASK}-%s ] PHY-RX-MODEL PHY802.11a" \
	% ([IP_WIRELESS_SUBNET_MDC_NET % IP_HOST_ID_NETWORK] * 4)
scenarioConfigFileObj.puts "
[ N#{MASK}-%s ] MAC-PROTOCOL MACDOT11
[ N#{MASK}-%s ] MAC-DOT11-ASSOCIATION DYNAMIC
[ N#{MASK}-%s ] MAC-DOT11-SSID #{SSID_WIRELESS_SUBNET_MDC_NET}
[ N#{MASK}-%s ] MAC-DOT11-AP NO
[ N#{MASK}-%s ] MAC-DOT11-SCAN-TYPE PASSIVE
[ N#{MASK}-%s ] DUMMY-MAC-DOT11-STATION-HANDOVER-RSS-TRIGGER YES
[ N#{MASK}-%s ] MAC-DOT11-STATION-HANDOVER-RSS-TRIGGER -83.0
[ N#{MASK}-%s ] MAC-DOT11-STA-PS-MODE-ENABLED NO
[ N#{MASK}-%s ] MAC-DOT11-DIRECTIONAL-ANTENNA-MODE NO
[ N#{MASK}-%s ] LLC-ENABLED YES" \
	% ([IP_WIRELESS_SUBNET_MDC_NET % IP_HOST_ID_NETWORK] * 10)
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# [Wired Subnet]"
scenarioConfigFileObj.puts "
SUBNET N#{MASK}-%s {%d, %d} %d %d 0" \
	% [IP_WIRED_SUBNET % IP_HOST_ID_NETWORK, \
		itemRouter[-2], itemServer[-2],
		PLACEMENT_X_WIRED_SUBNET \
			+ TERRAIN_MARGIN, PLACEMENT_Y_SUBNET + TERRAIN_MARGIN]
scenarioConfigFileObj.puts "
[ N#{MASK}-%s ] MAC-PROTOCOL MAC802.3
[ N#{MASK}-%s ] SUBNET-DATA-RATE 100000000
[ N#{MASK}-%s ] MAC802.3-MODE HALF-DUPLEX
[ N#{MASK}-%s ] SUBNET-PROPAGATION-DELAY 2.5US
[ N#{MASK}-%s ] LLC-ENABLED YES
[ N#{MASK}-%s ] NETWORK-PROTOCOL IP
[ N#{MASK}-%s ] DUMMY-FIXED-COMMS YES

[ N#{MASK}-%s ] ARP-ENABLED YES
[ N#{MASK}-%s ] ARP-CACHE-EXPIRE-INTERVAL 20M" \
	% ([IP_WIRED_SUBNET % IP_HOST_ID_NETWORK] * 9)
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# Node Configuration"
scenarioConfigFileObj.puts
for j in 0...nodes.size
	node = nodes[j]
	scenarioConfigFileObj.puts "[%d] HOSTNAME %s" \
		% [node[0], ROLES_HOSTNAME_STR[node[1]] % node[0]]
end
scenarioConfigFileObj.puts "
[%d] NODE-PLACEMENT FILE
[%d] NODE-PLACEMENT FILE
[%d] NODE-PLACEMENT FILE
[%d] NODE-PLACEMENT FILE
[%d thru %d] NODE-PLACEMENT FILE
[%d thru %d] NODE-PLACEMENT FILE" \
	% [itemServer[-2], itemRouter[-2], itemSwitch[-2], \
		itemMDC[-2], \
		listAP[0][-2], listAP[-1][-2], \
		listDS[0][-2], listDS[-1][-2]]
scenarioConfigFileObj.puts "
[%d] MOBILITY-POSITION-GRANULARITY 1.0
[%d] MOBILITY FILE" % ([itemMDC[-2]] * 2)
scenarioConfigFileObj.puts "
[%d thru %d] GUI-NODE-2D-ICON AccessPoint.png
[%d] GUI-NODE-2D-ICON devices/web_cluster.png
[%d] GUI-NODE-2D-ICON devices/router-color.png" \
	% [listAP[0][-2], listAP[-1][-2], \
		itemServer[-2], \
		itemRouter[-2]]
scenarioConfigFileObj.puts "
[%d thru %d] ARP-ENABLED YES
[%d thru %d] LLC-ENABLED YES" \
	% ([nodes[0][0], nodes[-1][0]] * 2)
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# Hierarchy Configuration"
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# Interface Configuration"
scenarioConfigFileObj.puts
allAddresses = []
setAddressesAP = []
setAddressesDS = []
scenarioConfigFileObj.puts "[%d] NETWORK-PROTOCOL[0] IP
[%d] IP-ADDRESS[0] %s # Server: Wired" \
	% ([itemServer[-2]] * 2 + [IP_WIRED_SUBNET % itemServer[-1]])
allAddresses << IP_WIRED_SUBNET % itemServer[-1]
# scenarioConfigFileObj.puts "[%d] NETWORK-PROTOCOL[0] IP
# [%d] IP-ADDRESS[0] %s # Router: Wireless #{SSID_WIRELESS_SUBNET_SIMU_NET}" \
# % ([itemRouter[-2]] * 2 + [IP_WIRELESS_SUBNET_SIMU_NET % itemRouter[-1]])
switchInterfaceNum = 0
switchPortMap = []
scenarioConfigFileObj.puts "[%d] NETWORK-PROTOCOL[0] IP
[%d] IP-ADDRESS[0] %s # Router: Wired" \
	% ([itemRouter[-2]] * 2 + [IP_WIRED_SUBNET % itemRouter[-1]])
scenarioConfigFileObj.puts "[%d] NETWORK-PROTOCOL[1] IP
[%d] IP-ADDRESS[1] %s # Router: Link" \
	% ([itemRouter[-2]] * 2 + [IP_LINKS_SWITCH % itemRouter[-1]])
switchPortAddress = IP_LINKS_SWITCH % [itemRouter[-1][0] + 2, itemRouter[-1][1]]
allAddresses << IP_WIRED_SUBNET % itemRouter[-1]
allAddresses << IP_LINKS_SWITCH % itemRouter[-1]
allAddresses << switchPortAddress
scenarioConfigFileObj.puts "[%d] NETWORK-PROTOCOL[%d] IP
[%d] IP-ADDRESS[%d] %s" \
	% [itemSwitch[-2], switchInterfaceNum, \
		itemSwitch[-2], switchInterfaceNum, \
		switchPortAddress]
switchInterfaceNum += 1
switchPortMap << [itemRouter[-2], IP_LINKS_SWITCH % itemRouter[-1], \
	switchPortAddress]
scenarioConfigFileObj.puts "[%d] NETWORK-PROTOCOL[0] IP
[%d] IP-ADDRESS[0] %s # Mobile Data Collector: Wireless " \
	% ([itemMDC[-2]] * 2 + [IP_WIRELESS_SUBNET_SIMU_NET % itemMDC[-1]]) \
	+ "#{SSID_WIRELESS_SUBNET_SIMU_NET}"
scenarioConfigFileObj.puts "[%d] NETWORK-PROTOCOL[1] IP
[%d] IP-ADDRESS[1] %s # Mobile Data Collector: Wireless " \
	% ([itemMDC[-2]] * 2 + [IP_WIRELESS_SUBNET_MDC_NET % itemMDC[-1]]) \
	+ "#{SSID_WIRELESS_SUBNET_MDC_NET}"
allAddresses << IP_WIRELESS_SUBNET_SIMU_NET % itemMDC[-1]
allAddresses << IP_WIRELESS_SUBNET_MDC_NET % itemMDC[-1]
# setAddressesAP << IP_WIRELESS_SUBNET_MDC_NET % itemMDC[-1]
scenarioConfigFileObj.puts
for j in 0...listAP.size
	itemAP = listAP[j]
	scenarioConfigFileObj.puts "[%d] NETWORK-PROTOCOL[0] IP" % itemAP[-2]
	scenarioConfigFileObj.puts "[%d] IP-ADDRESS[0] %s" \
		% [itemAP[-2], IP_WIRELESS_SUBNET_SIMU_NET % itemAP[-1]]
	scenarioConfigFileObj.puts "[%d] NETWORK-PROTOCOL[1] IP" % itemAP[-2]
	scenarioConfigFileObj.puts "[%d] IP-ADDRESS[1] %s" \
		% [itemAP[-2], IP_LINKS_SWITCH % itemAP[-1]]
	scenarioConfigFileObj.puts "[%d] NETWORK-PROTOCOL[%d] IP" \
		% [itemSwitch[-2], switchInterfaceNum]
	switchPortAddress = IP_LINKS_SWITCH \
		% convertItemIndexToHostId(j, offset=true)
	setAddressesAP << IP_WIRELESS_SUBNET_SIMU_NET % itemAP[-1]
	allAddresses << IP_WIRELESS_SUBNET_SIMU_NET % itemAP[-1]
	allAddresses << IP_LINKS_SWITCH % itemAP[-1]
	allAddresses << switchPortAddress
	scenarioConfigFileObj.puts "[%d] IP-ADDRESS[%d] %s" \
		% [itemSwitch[-2], switchInterfaceNum, \
			switchPortAddress]
	switchInterfaceNum += 1
	switchPortMap << [itemAP[-2], IP_LINKS_SWITCH % itemAP[-1], \
		switchPortAddress]
end
scenarioConfigFileObj.puts
for j in 0...listDS.size
	itemDS = listDS[j]
	scenarioConfigFileObj.puts "[%d] NETWORK-PROTOCOL[0] IP" % itemDS[-2]
	scenarioConfigFileObj.puts "[%d] IP-ADDRESS[0] %s" \
		% [itemDS[-2], IP_WIRELESS_SUBNET_MDC_NET % itemDS[-1]]
	setAddressesDS << IP_WIRELESS_SUBNET_MDC_NET % itemDS[-1]
	allAddresses << IP_WIRELESS_SUBNET_MDC_NET % itemDS[-1]
end
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# Node Configuration"
scenarioConfigFileObj.puts "
[%d] SWITCH YES" % itemSwitch[-2]
for j in 0...switchPortMap.size
	scenarioConfigFileObj.puts "[%d] SWITCH-PORT-MAP[%d] %s" \
		% [itemSwitch[-2], j + 1, switchPortMap[j][2]]
end
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# Links"
# for j in 0...switchPortMap.size
# 	switchPort = switchPortMap[j]
# 	scenarioConfigFileObj.puts "
# LINK N#{MASK}-%s { %d, %d }
# [ %s %s ] LINK-MAC-PROTOCOL ABSTRACT
# [ %s %s ] DUMMY-GUI-SYMMETRIC-LINK YES
# [ %s %s ] NETWORK-PROTOCOL IP" \
# 	% ([IP_LINKS_SWITCH % IP_HOST_ID_NETWORK, switchPort[0], itemSwitch[-2]] \
# 		+ [switchPort[1], switchPort[2]] * 3)
# end
scenarioConfigFileObj.puts "
LINK N#{MASK}-%s { %d, %d }
[ %s %s ] LINK-MAC-PROTOCOL ABSTRACT
[ %s %s ] DUMMY-GUI-SYMMETRIC-LINK YES
[ %s %s ] NETWORK-PROTOCOL IP" \
	% ([IP_LINKS_SWITCH % IP_HOST_ID_NETWORK, itemRouter[-2], itemSwitch[-2]] \
		+ [IP_LINKS_SWITCH % itemRouter[-1], \
			IP_LINKS_SWITCH % [itemRouter[-1][0] + 2, itemRouter[-1][1]]] * 3)
for j in 0...listAP.size
	itemAP = listAP[j]
	scenarioConfigFileObj.puts "
LINK N#{MASK}-%s { %d, %d }
[ %s %s ] LINK-MAC-PROTOCOL ABSTRACT
[ %s %s ] DUMMY-GUI-SYMMETRIC-LINK YES
[ %s %s ] NETWORK-PROTOCOL IP" \
	% ([IP_LINKS_SWITCH % IP_HOST_ID_NETWORK, itemAP[-2], itemSwitch[-2]] \
		+ [IP_LINKS_SWITCH % itemAP[-1], \
			IP_LINKS_SWITCH % convertItemIndexToHostId(j, offset=true)] * 3)
	scenarioConfigFileObj.puts "[ %s %s ] LINK-BANDWIDTH %d" \
		% [IP_LINKS_SWITCH % itemAP[-1], \
			IP_LINKS_SWITCH % convertItemIndexToHostId(j, offset=true), \
			itemAP[1] * 1000]
end
scenarioConfigFileObj.puts
scenarioConfigFileObj.puts "# IP Configuration"
scenarioConfigFileObj.puts "
[%s] LINK-PROPAGATION-DELAY #{PROPOGATION_DELAY_SERVER_ROUTER}MS
[%s] LINK-BANDWIDTH 10000000" \
	% ([[IP_WIRED_SUBNET % itemServer[-1], \
		IP_WIRED_SUBNET % itemRouter[-1]].join(" ")] * 2)
setAddressesAPWithMDC = setAddressesAP \
	+ [IP_WIRELESS_SUBNET_MDC_NET % itemMDC[-1]];
scenarioConfigFileObj.puts "
[%s] MAC-DOT11-AP-SUPPORT-PS-MODE NO
[%s] MAC-DOT11-DTIM-PERIOD 3
[%s] MAC-DOT11-SCAN-TYPE DISABLED
[%s] MAC-DOT11-BEACON-INTERVAL 200
[%s] MAC-DOT11-RELAY-FRAMES YES
[%s] MAC-DOT11-AP YES
[%s] MAC-DOT11-PC NO
[%s] MAC-ADDRESS-CONFIG-FILE #{SCENARIO_NAME}.mac-address
[%s] DUMMY-MAC-ADDRESS YES" % ([setAddressesAPWithMDC.join(" ")] * 9)
scenarioConfigFileObj.puts "
[%s] IP-QUEUE-PRIORITY-QUEUE-SIZE[0] 150000
[%s] IP-QUEUE-TYPE[0] FIFO
[%s] IP-QUEUE-PRIORITY-QUEUE-SIZE[1] 150000
[%s] IP-QUEUE-TYPE[1] FIFO
[%s] IP-QUEUE-PRIORITY-QUEUE-SIZE[2] 150000
[%s] IP-QUEUE-TYPE[2] FIFO" % ([setAddressesAPWithMDC.join(" ")] * 6)
scenarioConfigFileObj.puts "
[%s] PHY802.11a-TX-POWER--6MBPS #{TX_POWER_AP}
[%s] PHY802.11a-TX-POWER--9MBPS #{TX_POWER_AP}
[%s] PHY802.11a-TX-POWER-12MBPS #{TX_POWER_AP}
[%s] PHY802.11a-TX-POWER-18MBPS #{TX_POWER_AP}
[%s] PHY802.11a-TX-POWER-24MBPS #{TX_POWER_AP}
[%s] PHY802.11a-TX-POWER-36MBPS #{TX_POWER_AP}
[%s] PHY802.11a-TX-POWER-48MBPS #{TX_POWER_AP}
[%s] PHY802.11a-TX-POWER-54MBPS #{TX_POWER_AP}" % \
	([setAddressesAP.join(" ")] * 8)
scenarioConfigFileObj.puts "
[%s] PHY802.11a-TX-POWER--6MBPS #{TX_POWER_DS}
[%s] PHY802.11a-TX-POWER--9MBPS #{TX_POWER_DS}
[%s] PHY802.11a-TX-POWER-12MBPS #{TX_POWER_DS}
[%s] PHY802.11a-TX-POWER-18MBPS #{TX_POWER_DS}
[%s] PHY802.11a-TX-POWER-24MBPS #{TX_POWER_DS}
[%s] PHY802.11a-TX-POWER-36MBPS #{TX_POWER_DS}
[%s] PHY802.11a-TX-POWER-48MBPS #{TX_POWER_DS}
[%s] PHY802.11a-TX-POWER-54MBPS #{TX_POWER_DS}" % \
	([setAddressesDS.join(" ")] * 8)
scenarioConfigFileObj.puts "
[%s] PHY802.11a-TX-POWER--6MBPS #{TX_POWER_MDC}
[%s] PHY802.11a-TX-POWER--9MBPS #{TX_POWER_MDC}
[%s] PHY802.11a-TX-POWER-12MBPS #{TX_POWER_MDC}
[%s] PHY802.11a-TX-POWER-18MBPS #{TX_POWER_MDC}
[%s] PHY802.11a-TX-POWER-24MBPS #{TX_POWER_MDC}
[%s] PHY802.11a-TX-POWER-36MBPS #{TX_POWER_MDC}
[%s] PHY802.11a-TX-POWER-48MBPS #{TX_POWER_MDC}
[%s] PHY802.11a-TX-POWER-54MBPS #{TX_POWER_MDC}" % \
	([IP_WIRELESS_SUBNET_SIMU_NET % itemMDC[-1]] * 8)
scenarioConfigFileObj.puts "
[%s] PHY802.11a-TX-POWER--6MBPS #{TX_POWER_MDC}
[%s] PHY802.11a-TX-POWER--9MBPS #{TX_POWER_MDC}
[%s] PHY802.11a-TX-POWER-12MBPS #{TX_POWER_MDC}
[%s] PHY802.11a-TX-POWER-18MBPS #{TX_POWER_MDC}
[%s] PHY802.11a-TX-POWER-24MBPS #{TX_POWER_MDC}
[%s] PHY802.11a-TX-POWER-36MBPS #{TX_POWER_MDC}
[%s] PHY802.11a-TX-POWER-48MBPS #{TX_POWER_MDC}
[%s] PHY802.11a-TX-POWER-54MBPS #{TX_POWER_MDC}" % \
	([IP_WIRELESS_SUBNET_MDC_NET % itemMDC[-1]] * 8)
scenarioConfigFileObj.puts
scenarioConfigFileObj.close

puts "Copying to file: " + scenarioTestConfigFileName
FileUtils.cp(scenarioConfigFileName, scenarioTestConfigFileName)

puts "Writing to file: " + scenarioTestConfigFileName
scenarioTestConfigFileObj = File.open(scenarioTestConfigFileName, "a")
scenarioTestConfigFileObj.puts "# Test Configuration"
scenarioTestConfigFileObj.puts "
APP-CONFIG-FILE #{SCENARIO_NAME}.test.app
NODE-POSITION-FILE #{SCENARIO_NAME}.test.nodes"
scenarioTestConfigFileObj.puts
scenarioTestConfigFileObj.close

puts "Writing to file: " + scenarioConfigFileName
scenarioConfigFileObj = File.open(scenarioConfigFileName, "a")
scenarioConfigFileObj.puts "# Case Configuration"
scenarioConfigFileObj.puts "
APP-CONFIG-FILE #{SCENARIO_NAME}.app
NODE-POSITION-FILE #{SCENARIO_NAME}.nodes"
scenarioConfigFileObj.puts
scenarioConfigFileObj.close

# Generate node placement configuration
puts "Writing to file: " + scenarioNodesFileName
scenarioNodesFileObj = File.open(scenarioNodesFileName, "w")
nodeLineFormat = "%d 0 (%.4f, %.4f, %.4f) 0 0"
nodeLineFormatDelayed = "%d #{MDC_WAIT_BEFORE_START}S (%.4f, %.4f, %.4f) 0 0"
scenarioNodesFileObj.puts nodeLineFormat \
	% [itemSwitch[-2], \
		TERRAIN_MARGIN + PLACEMENT_X_SWITCH, \
		TERRAIN_MARGIN + PLACEMENT_Y_SUBNET, 0]
scenarioNodesFileObj.puts nodeLineFormat \
	% [itemRouter[-2], \
		TERRAIN_MARGIN + PLACEMENT_X_ROUTER, \
		TERRAIN_MARGIN + PLACEMENT_Y_ROUTER, 0]
scenarioNodesFileObj.puts nodeLineFormat \
	% [itemServer[-2], \
		TERRAIN_MARGIN + PLACEMENT_X_SERVER, \
		TERRAIN_MARGIN + PLACEMENT_Y_SERVER, 0]
scenarioNodesFileObj.puts nodeLineFormat \
	% [itemMDC[-2], \
		TERRAIN_MARGIN + 0, \
		TERRAIN_MARGIN + PLACEMENT_Y_PATH, 0]
scenarioNodesFileObj.puts nodeLineFormatDelayed \
	% [itemMDC[-2], \
		TERRAIN_MARGIN + 0, \
		TERRAIN_MARGIN + PLACEMENT_Y_PATH, 0]
for j in 0...listAP.size
	itemAP = listAP[j]
	scenarioNodesFileObj.puts nodeLineFormat \
		% [itemAP[-2], \
			TERRAIN_MARGIN + itemAP[0], \
			TERRAIN_MARGIN + PLACEMENT_Y_PATH, 0]
end
for j in 0...listDS.size
	itemDS = listDS[j]
	scenarioNodesFileObj.puts nodeLineFormat \
		% [itemDS[-2], \
			TERRAIN_MARGIN + itemDS[0], \
			TERRAIN_MARGIN + PLACEMENT_Y_PATH, 0]
end
scenarioNodesFileObj.puts
scenarioNodesFileObj.close

puts "Copying to file: " + scenarioTestNodesFileName
FileUtils.cp(scenarioNodesFileName, scenarioTestNodesFileName)

TIME_SITES_TEST = { \
	ROLE_AP => 120, \
	ROLE_DS => 120 \
}

puts "Writing to file: " + scenarioTestNodesFileName
scenarioNodesConfigFileObj = File.open(scenarioTestNodesFileName, "a")
xNode = 0
tNode = MDC_WAIT_BEFORE_START
listSites = []
for itemAP in listAP
	listSites << [itemAP[0], ROLE_AP]
end
for itemDS in listDS
	listSites << [itemDS[0], ROLE_DS]
end
listSites.sort! {|x, y| x[0] <=> y[0]}
nodeLineFormat = "#{itemMDC[-2]} %dS (%.4f, %.4f, %.4f) 0 0"
for itemSite in listSites
	tNode += (1.0 * (itemSite[0] - xNode) / itemMDC[0]).round
	xNode = itemSite[0]
	scenarioNodesConfigFileObj.puts nodeLineFormat \
		% [tNode, TERRAIN_MARGIN + xNode, TERRAIN_MARGIN + PLACEMENT_Y_PATH, 0]
	tNode += TIME_SITES_TEST[itemSite[1]]
	scenarioNodesConfigFileObj.puts nodeLineFormat \
		% [tNode, TERRAIN_MARGIN + xNode, TERRAIN_MARGIN + PLACEMENT_Y_PATH, 0]
	scenarioNodesConfigFileObj
end
tNode += SIMULATION_WAIT_AFTER_END
scenarioNodesConfigFileObj.puts
scenarioNodesConfigFileObj.close

puts "Writing to file: " + scenarioTestConfigFileName
scenarioTestConfigFileObj = File.open(scenarioTestConfigFileName, "a")
scenarioTestConfigFileObj.puts "# Test Configuration"
scenarioTestConfigFileObj.puts "
SIMULATION-TIME #{tNode}S"
scenarioTestConfigFileObj.puts
scenarioTestConfigFileObj.close

# Generate application specification
puts "Writing to file: " + scenarioAppFileName
scenarioAppFileObj = File.open(scenarioAppFileName, "w")
scenarioAppFileObj.puts "UP CLOUD #{itemServer[-2]}"
for j in 0...listDS.size
	itemDS = listDS[j]
	scenarioAppFileObj.puts "UP DATA %d %d %d %d %d %.4f" \
		% [itemDS[-2], itemMDC[-2], \
			j + 1, \
			itemDS[1], itemDS[2] + MDC_WAIT_BEFORE_START, itemDS[3]]
end
scenarioAppFileObj.puts
scenarioAppFileObj.close

puts "Copying to file: " + scenarioTestAppFileName
FileUtils.cp(scenarioAppFileName, scenarioTestAppFileName)

puts "Writing to file: " + scenarioTestAppFileName
scenarioAppConfigFileObj = File.open(scenarioTestAppFileName, "a")
scenarioAppConfigFileObj.puts "UP MDC #{itemMDC[-2]} #{itemServer[-2]} -"
scenarioAppConfigFileObj.puts
scenarioAppConfigFileObj.close

puts "Writing to file: " + scenarioAppFileName
scenarioAppFileObj = File.open(scenarioAppFileName, "a")
scenarioAppFileObj.puts "UP MDC #{itemMDC[-2]} #{itemServer[-2]}"
scenarioAppFileObj.puts
scenarioAppFileObj.close

def convertItemIndexToHardwareAddress(index)
	raise ArgumentError if index + MAC_ADDRESS_OFFSET + 1 > 256 * 256
	byte4 = (index + MAC_ADDRESS_OFFSET).div 256
	byte5 = (index + MAC_ADDRESS_OFFSET) % 256
	return "#{MAC_ADDRESS_PREFIX}:%02x:%02x" % [byte4, byte5]
end

# Generate MAC address specification
puts "Writing to file: " + scenarioHardwareAddressFileName
scenarioHardwareAddressFileObj = File.open(scenarioHardwareAddressFileName, "w")
for j in 0...listAP.size
	itemAP = listAP[j]
	scenarioHardwareAddressFileObj.puts "%d %d ETHERNET %s" \
		% [itemAP[-2], 0, convertItemIndexToHardwareAddress(j)]
end
scenarioHardwareAddressFileObj.puts
scenarioHardwareAddressFileObj.close

# Generate display configuration
puts "Writing to file: " + scenarioDisplayFileName
scenarioDisplayFileObj = File.open(scenarioDisplayFileName, "w")
scenarioDisplayFileObj.puts "[General]"
scenarioDisplayFileObj.puts "
showAnimation=false
showLegend=true
showNodeIds=true
showHierarchyDisplay=true
showIpAddresses=false
showWiredLinks=true
showAppLinks=true
showGrid=true
showBgImages=true
showWeather=true
showHierarchyNames=false
showPatterns=false
showNightView=false
showHostNames=false
showInterfaceNames=false
showWirelessSubnets=true
showSatelliteLinks=true
showRuler=true
showWaypoint=true
showAnnotations=true
showAsIds=false
showQueues=false
showAxes=false
nodeOrientationIcon=true
nodeOrientationArrow=false"
scenarioDisplayFileObj.puts
scenarioDisplayFileObj.close

# Generate test script
puts "Writing to file: " + scenarioTestScriptName
scenarioTestScriptObj = File.open(scenarioTestScriptName, "w")
scenarioTestScriptObj.puts \
	"$QUALNET_HOME/bin/qualnet #{SCENARIO_NAME}.test.config"
scenarioTestScriptObj.puts
scenarioTestScriptObj.close
FileUtils.chmod "u+x", scenarioTestScriptName

# Copy configuration file
puts "Copying to file: " + deploymentFileName
FileUtils.cp configFileName, deploymentFileName

#
puts
