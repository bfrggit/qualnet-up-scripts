# Author: Charles ZHU
#

class Array
	def sum
		inject(0.0) { |result, el| result + el }
	end

	def mean 
		sum / size
	end
end

MY_NAME = "find_rewards.rb"

if ARGV.size != 1
	STDERR.puts "Usage: ruby #{MY_NAME} DIRECTORY"
	# puts
	exit
end
batchDirName = File.expand_path(ARGV[0])

if not File.directory? batchDirName
	STDERR.puts "Invalid batch directory: " + batchDirName
	exit
end

RUBY = `which ruby`.strip

serverOutputNameWildcard = "server_server*.out"
serverOutputPathReg = \
	/(\d+)\/case\_(\d+)\/case\/([A-Za-z\_\d]+)\/rand\_(\d+)\/server\_server\d+\.out$/

outFilesText = `find #{batchDirName} -name #{serverOutputNameWildcard}`
outFilesText.gsub!(/\r\n?/, "\n")
outFilesList = []
outFilesText.each_line do |line|
	path = line.strip
	regMatch = serverOutputPathReg.match path
	next if not regMatch
	outFilesList << [path, \
		regMatch[1].to_i, regMatch[2].to_i, regMatch[3], regMatch[4].to_i]
end
outFilesList.sort_by! {|x| x[1..4]}

# Collect data set information
algorithms = Hash.new
variableXs = Hash.new
numCases = 0
for outFile in outFilesList
	variableXs[outFile[1]] = variableXs.size if not variableXs[outFile[1]]
	numCases = [numCases, outFile[2]].max
	algorithms[outFile[3]] = algorithms.size if not algorithms[outFile[3]]
end
# p algorithms
# p variableXs
algorithmsRev = [nil] * algorithms.size
variableXsRev = [nil] * variableXs.size
algorithms.each do |key, value|
	algorithmsRev[value] = key
end
variableXs.each do |key, value|
	variableXsRev[value] = key
end

# Validate deployment files
valFilesList = []
for outFile in outFilesList
	deploymentFilePath = \
		File.expand_path(File.dirname(outFile[0]) + "/../../up.deployment")
	next if not File.file? deploymentFilePath
	valFilesList << outFile + [deploymentFilePath]
end
valFilesList.sort_by! {|x| x[1..4]}

# Calculate rewards
table = []
for j in 0...variableXs.size
	table << []
	for k in 0...algorithms.size
		table[j] << []
	end
end

for valFile in valFilesList
	cmd = "#{RUBY} calc_rewards.rb #{valFile[-1]} #{valFile[0]}"
	valFile << `#{cmd}`.strip.to_f
	if valFile[-1].class == 9.class or valFile[-1].class == 9.0.class
		table[variableXs[valFile[1]]][algorithms[valFile[3]]] << valFile[-1]
	end
end

puts "var," + algorithmsRev.join(",")
for j in 0...table.size
	for k in 0...table[j].size
		table[j][k] = table[j][k].mean
	end
	puts variableXsRev[j].to_s + "," + table[j].map {|x| "%.6f" % x}.join(",")
end
