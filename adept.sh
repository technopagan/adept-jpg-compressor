#!/usr/bin/env bash 

###############################################################################
#
# Bash script to automate adaptive JPEG compression using common CLI tools
#
# Usage: bash adept.sh /path/to/image.jpg
#
###############################################################################
# 
# Brief overview of the script's mode of operation:
#
# The input JPG gets sliced into tiles, sized as a multiple of 8 due to the
# nature of the JPG algorithm. The tiles are run through an all-directional
# Sobel Edge Detect algorithm. The resulting tiles get further reduced to
# 2-color black+white PNGs with limited palette. 
#
# These PNGs are ideal to analyse the gray channel mean value and use it 
# as a single integer indicator to judge the perceivable complexity of 
# the current image segment.
#
# Tiles with low complexity contents get compressed stronger than others.
# At reassemlby, this leads to savings in image bytesize while maintaining
# good visual quality because no compression artefacts occur in areas of
# high-complexity or sharp contrasts. 
# 
###############################################################################
# Tools that need to be pre-installed:
#
#	* ImageMagick >= v.6.6
#
# 	* JPEGOptim
#
#	* JPEGRescan Perl Script for lossless JPG compression
#	  http://github.com/kud/jpegrescan
# 
# Note: Additonal tools are required to run Adept, such as "bc", "sort",
# "rm" and Bash 4.x. As all of these tools are provided by lsbcore, core-utils
# or similar default packages, we can expect them to be always available.
#
###############################################################################
# 
# This software is published under the BSD licence 3.0
# 
# Copyright (c) 2013, Tobias Baldauf
# All rights reserved.
#
# Mail: kontakt@tobias-baldauf.de
# Web: http://who.tobias.is/
# Twitter: @tbaldauf
#
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
#
#	* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
#
#	* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
#
#	* Neither the name of the author nor the names of contributors may be used to endorse or promote products derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
###############################################################################



###############################################################################
# USER CONFIGURABLE PARAMETERS
###############################################################################

# Default JPG quality setting, either inherited or defined as an integer of 0-100
# Default: inherit
DEFAULTCOMPRESSIONRATE="inherit"

# JPEG quality setting for areas of the image deemed suitable for high compression in an integer of 0-100
# Default: 66
HIGHCOMPRESSIONRATE="66"

# Suffix string to attach to the output JPG filename, e.g. '_adept_compress'
# If deliberatly set empty (''), the input JPG will be replaced with the new compressed JPG
OUTPUTFILESUFFIX="_adept_compress"



###############################################################################
# RUNTIME VARIABLES (usually do not require tuning by user)
###############################################################################

# Accept the jpg filename as a parameter
FILE="$1"

# Retrieve clean filename without extension
CLEANFILENAME=${FILE%.jp*g}

# Retrieve only the file extension
FILEEXTENSION=${FILE##*.}

# Retrieve clean path directory without filename
CLEANPATH="${FILE%/*}"
# If the JPEG is in the same direcctory as Adept, empty the path variable
# Or if it is set, make sure the path has a trailing slash
if  [ "$CLEANPATH" == "$FILE" ]; then
	CLEANPATH=""
else
	CLEANPATH="$CLEANPATH/"	
fi

# Storage location for all temporary files during runtime
# Use locations like /dev/shm (/run/shm/ in Ubuntu) to save files in Shared Memory Space (RAM) to avoid disk i/o troubles
TILESTORAGEPATH="/dev/shm/"

# Square dimensions for all temporary tiles. Tile size heavily influences compression efficiency at the cost of runtime performance
# E.g. a tile size of 8 yields maximum compression results while taking several minutes of runtime
# If you chose to manually adjust tile size, only use multiples of 8 (8/16/32/64/128/256)
# Default: autodetect
TILESIZE="autodetect"

# Control noise threshold for tiles. Higher threshold leads to more tiles being marked as compressable at the cost of image quality
# Default: 0.333 - only raise/lower in small steps, e.g. 0.175, 0.333, 0.5 etc
BLACKWHITETHRESHOLD="0.333"

# Setup a global counter for attempts on bwthreshold optimization 
BWTHRESHOLD_ITERATION_COUNT=0



###############################################################################
# MAIN PROGRAM
###############################################################################

prepwork() {
	find_tool IDENTIFY_COMMAND identify
	find_tool CONVERT_COMMAND convert
	find_tool MONTAGE_COMMAND montage
	find_tool JPEGOPTIM_COMMAND jpegoptim
	find_tool JPEGRESCAN_COMMAND jpegrescan
	validate_image VALIDJPEG "${FILE}"
}

main() {
	find_image_dimension IMAGEWIDTH "${FILE}" 'w'
	find_image_dimension IMAGEHEIGHT "${FILE}" 'h'
	optimize_tile_size TILESIZE ${TILESIZE} ${IMAGEWIDTH} ${IMAGEHEIGHT}
	optimize_bwthreshold BLACKWHITETHRESHOLD "${FILE}" ${BLACKWHITETHRESHOLD}
	slice_image_to_ram "${FILE}" ${TILESIZE} ${TILESTORAGEPATH}
	estimate_tile_content_complexity_and_compress
	calculate_tile_count_for_reassembly TILEROWS ${IMAGEHEIGHT} ${TILESIZE}
	calculate_tile_count_for_reassembly TILECOLUMNS ${IMAGEWIDTH} ${TILESIZE}
	reassemble_tiles_into_final_image
}



###############################################################################
# FUNCTIONS
###############################################################################

# Find the proper handle for the required commandline tool
# This function can take an optional third parameter when being called to manually define the path to the CLI tool
function find_tool () {
	# Define local variables to work with
    local  __result=$1
    local  __tool=$2
    local  __customtoolpath=$3
    # Array of possible tool locations: name, name as ALL-CAPS, /usr/bin/name, /usr/local/bin/name and custom path
	local __possibletoollocations=(${__tool} ${__tool^^} /usr/bin/${__tool} /usr/local/bin/${__tool} ${__customtoolpath})
	# For each possible tool location, test if its actually available there
	for i in "${__possibletoollocations}"; do
		local __commandlinetool=$(type -p $i)
		# If 'type -p' returned something, we now have our proper handle
		if [ "$__commandlinetool" ]; then
			break
		fi
	done
	# In case none of the given inputs works, apologize & quit
	if [ ! "$__commandlinetool" ]; then
		echo "Unable to find ${__tool}. Please ensure that it is installed. If necessary, set its CLI path+name in the find_tool function call and then retry."
		exit 1
	fi
	# Return the result
	eval $__result="'${__commandlinetool}'"
}

# Validate that we are working on an actual intact JPEG image before launch
function validate_image {
	# Define local variables to work with
    local  __result=$1
    local  __imagetovalidate=$2
    # If the script is called without an input file, explain how to use it
	# We don't "exit 1" here anymore because our unit tests source the script
	# and would abort if "exit 1" was called
	if  [ ! -f "$__imagetovalidate" ]; then
		local  __validationresult=0
		echo "Missing input JPEG. Usage: $0 /path/to/jpeg/image.jpg"
	else
		# Use IM identify to read the file magic of the input file to validate it's a JPEG
		local  __filemagic=$(${IDENTIFY_COMMAND} -format %m "$__imagetovalidate")
		if [ "$__filemagic" == "JPEG" ] ; then
			# Set a switch that it is ok to work on the input file, launching the main funtion
			local  __validationresult=1
		fi
	fi
	# Return the result
	eval $__result="'${__validationresult}'"
}

# Read width (%w) or height (%h) of the input image via IM identify
function find_image_dimension {
	# Define local variables to work with
    local  __result=$1
    local  __imagetomeasure=$2
    local  __dimensiontomeasure=$3
    # Read the width or height of the input image into a global variable
	local  __imagedimension=$(${IDENTIFY_COMMAND} -format '%'${__dimensiontomeasure} ${__imagetomeasure})
	# Return the result
	eval $__result="'${__imagedimension}'"
}

# Tile size is the no.1 performance bottleneck for Adept, so it is important we pick an optimal tile size for the input image dimensions
# Also, the number of tiles to be recombined affects compression efficiency and salient areas within an image tend to have similar dimensional
# relations to total image size, so it makes sense to change tile size accordingly
function optimize_tile_size {
	# Define local variables to work with
    local  __result=$1
    local  __optimaltilesize=$2
    local  __currentimagewidth=$3
    local  __currentimageheight=$4
    # The default "autodetect" setting causes Adept to find a suitable tile size according to image dimensions
    if [ "$TILESIZE" == "autodetect" ] ; then
		# Pick the smaller of the two dimensions of the image as the decisive integer for tile size
		local  __decisivedimension=${__currentimageheight}
		if (( $(echo "$IMAGEWIDTH < $__decisivedimension" | bc -l) )); then
			__decisivedimension=${__currentimagewidth}
		fi    
		# For a series of sensible steps, change the tile size accordingly
		if (( $(echo "$__decisivedimension <= 128" | bc -l) )); then
			__optimaltilesize="8"
		elif (( $(echo "$__decisivedimension >= 129" | bc -l) )) && (( $(echo "$__decisivedimension <= 256" | bc -l) )); then
			__optimaltilesize="16"
		elif (( $(echo "$__decisivedimension >= 257" | bc -l) )) && (( $(echo "$__decisivedimension <= 512" | bc -l) )); then
			__optimaltilesize="32"
		elif (( $(echo "$__decisivedimension >= 513" | bc -l) )) && (( $(echo "$__decisivedimension <= 1024" | bc -l) )); then
			__optimaltilesize="64"
		elif (( $(echo "$__decisivedimension >= 1025" | bc -l) )) && (( $(echo "$__decisivedimension <= 2560" | bc -l) )); then
			__optimaltilesize="128"
		elif (( $(echo "$__decisivedimension >= 2561" | bc -l) )); then
			__optimaltilesize="256"
		else
			__optimaltilesize="64"
		fi
	# In case the user has changed the configuration from "autodetect" to a custom setting, respect & return this instead
	else
		__optimaltilesize=${TILESIZE}
	fi
	# Return the result
	eval $__result="'${__optimaltilesize}'"
}

# Determine a threshold value that has a good signal to noise ratio for the input image
function optimize_bwthreshold()
{
	# Define local variables to work with
    local  __bwthresholdresult=$1
    local  __filetoprocess=$2
    local  __bwthreshold=$3
    local  __actualbwmedian=''
    # Retrieve the black/white median decimal for the entire image to get an estimate on its complexity / noise level
    get_black_white_median __actualbwmedian ${__filetoprocess} ${TILESTORAGEPATH} ${__bwthreshold}
    # In case there is too much noise at the current $BLACKWHITETHRESHOLD setting, try to optimize it
    while (( $(echo "$__actualbwmedian > 50" | bc -l) )) && (( ${BWTHRESHOLD_ITERATION_COUNT} < 5 )); do
		__bwthreshold=$(echo "scale=4; ${__bwthreshold}+0.1" | bc -l)
		get_black_white_median __actualbwmedian ${__filetoprocess} ${TILESTORAGEPATH} ${__bwthreshold}
		((BWTHRESHOLD_ITERATION_COUNT++))
    done
    # Return result
	eval $__bwthresholdresult="'${__bwthreshold}'"
}

# Slice the input image into equally sized tiles
function slice_image_to_ram {
	# Define local variables to work with
	local  __filetoprocess=$1
	local  __currenttilesize=$2
	local  __currenttilestoragepath=$3
	# If $DEFAULTCOMPRESSIONRATE is set to "inherit", discover the input JPG quality 
	if [ "$DEFAULTCOMPRESSIONRATE" == "inherit" ] ; then
		DEFAULTCOMPRESSIONRATE=$(${IDENTIFY_COMMAND} -format "%Q" ${__filetoprocess})
	fi
	${CONVERT_COMMAND} "$__filetoprocess" -strip -quality "${DEFAULTCOMPRESSIONRATE}" -define jpeg:dct-method=float -crop "${__currenttilesize}"x"${__currenttilesize}" -set filename:tile "%[fx:page.y/${__currenttilesize}+1]x%[fx:page.x/${__currenttilesize}+1]" +repage +adjoin "${__currenttilestoragepath}${CLEANFILENAME##*/}_tile_%[filename:tile].${FILEEXTENSION}"
}

# For each tile, test if it is suitable for higher compression and if so, proceed
function estimate_tile_content_complexity_and_compress {
	# Fill an array with the paths+filenames of all the tiles we have just sliced so that we can work on each of them
	local  __tilesarray=(${TILESTORAGEPATH}${CLEANFILENAME##*/}_tile_*.${FILEEXTENSION})
	# Resort the freshly filled array from ASCII sort order to natural sort order so that filename_100 does not get processed before filename_1
	local  __tilesarray=($(printf '%s\n' "${__tilesarray[@]}"|sort -V))
	# Iterate over every created tile we have listed in our array
	for((i=0;i<${#__tilesarray[@]};i++)) ; do
		# Retrieve the black/white median decimal for each tile and store the result in $BWMEDIAN
		get_black_white_median BWMEDIAN ${__tilesarray[$i]} ${TILESTORAGEPATH} ${BLACKWHITETHRESHOLD}
		# If the gray channel median is below a defined threshold, the visible area in the current tile is very likely simple & rather monotonous and can safely be exposed to a higher compression rate 
		# Untouched JPGs simply stay at the defined default quality setting ($DEFAULTCOMPRESSIONRATE)
		if (( $(echo "$BWMEDIAN < 0.825" | bc -l) )); then
			# Here, we also experimented with bluring/smoothing of tiles to enhance JPEG compression, but results were insignificant
			${JPEGOPTIM_COMMAND} --max=${HIGHCOMPRESSIONRATE} -t -v --strip-all ${__tilesarray[$i]} >/dev/null 2>/dev/null
		fi
	done
}

# Measure the black/white median of a sobel+bw image to use it as an indicator for content complexity 
function get_black_white_median()
{
	# Define local variables to work with
    local  __result=$1
    local  __filetomeasure=$2
    local  __filenameandpath=${__filetomeasure%.jp*g}
    local  __filenameonly=${__filenameandpath##*/}
    local  __currenttilestoragepath=$3
    local  __newbwthreshold=$4
	# Run an all-directional Sobel edge detection on the tile to discover high contrast borders
	# These borders are areas JPG compression always has troubles with - so we will tread carefully if we detect them
	# Then convert the Sobel result to a 2-color black+white image (channel ALL enables us to not lose information in the process) so that we can easily count the pixels
	# The Threshold parameter is a basic noise filter - anything below it gets dropped so that our b/w-image is actually useful and not just pixelated noise
	# Then we run identify on the 2-color limited palette PNG8 to retrieve the mean for the gray channel
	# The result will be a decimal number (or zero) by which we can judge the visible object complexity in the current tile
    ${CONVERT_COMMAND} ${__filetomeasure} -define convolve:scale='!' -define morphology:compose=Lighten -morphology Convolve 'Sobel:>' "${__currenttilestoragepath}${__filenameonly}_sobel.${FILEEXTENSION}"
	${CONVERT_COMMAND} "${__currenttilestoragepath}${__filenameonly}_sobel.${FILEEXTENSION}" -channel All -random-threshold "${__newbwthreshold}%" "${__currenttilestoragepath}${__filenameonly}_sobel_bw.png"
	local __currentbwmedian=$(${IDENTIFY_COMMAND} -channel Gray -format "%[fx:255*mean]" "${__currenttilestoragepath}${__filenameonly}_sobel_bw.png")
	# Cleanup
	rm ${__currenttilestoragepath}${__filenameonly}_sobel.${FILEEXTENSION} ${__currenttilestoragepath}${__filenameonly}_sobel_bw.png
	# Return result
	eval $__result="'${__currentbwmedian}'"
}

# For the reassembly of the image, we need the count of rows and columns of tiles that were created
function calculate_tile_count_for_reassembly {
	# Define local variables to work with
    local  __result=$1
    local  __currentimagedimension=$2
    local  __currenttilesize=$3
	# Divide the height by tilesize using bc because Bash cannot handle floating point calculations
	local __tilecountdecimal=$(echo "scale=4; ${__currentimagedimension}/${__currenttilesize}" | bc -l)
	# Make use of Bash's behaviour of rounding down to see if we're tilecount = integer + 1
	local __tilecountroundeddown=$(echo $((${__currentimagedimension}/${__currenttilesize})))
	# Check if we need to +1 our integer because the decimal is larger than the integer
	if (( $(echo "$__tilecountdecimal > $__tilecountroundeddown" | bc -l) )); then
		local __tilecount=$(echo $((${__tilecountroundeddown}+1)))
	else
		local __tilecount=${__tilecountroundeddown}
	fi
	# Return result
	eval $__result="'${__tilecount}'"
}

# Now that we know the number of rows+columns, we use montage to recombine the now partially compressed tiles into a new coherant JPEG image
function reassemble_tiles_into_final_image {
	# We're piping the list of filenames to process by montage to "sort -V" to achieve natural sorting so that tilename_2_10.jpg actually is processed after tilename_2_9.jpg and not before tilename_2_1.jpg - otherwise the recombined image would be messed up 
	${MONTAGE_COMMAND} -strip -quality "${DEFAULTCOMPRESSIONRATE}" -mode concatenate -tile "${TILECOLUMNS}x${TILEROWS}" $(ls "${TILESTORAGEPATH}${CLEANFILENAME##*/}"_tile_*.${FILEEXTENSION} | sort -V) "${CLEANPATH}${CLEANFILENAME##*/}${OUTPUTFILESUFFIX}".${FILEEXTENSION}

	# During montage reassembly, the resulting image received bytes of padding due to the way the JPEG compression algorithm works on tiles not sized as a multiple of 8   
	# So we run jpegrescan on the final image to losslessly remove this padding and make the output JPG progressive
	${JPEGRESCAN_COMMAND} -q -s "${CLEANFILENAME##*/}${OUTPUTFILESUFFIX}".${FILEEXTENSION} "${CLEANFILENAME##*/}${OUTPUTFILESUFFIX}".${FILEEXTENSION}

	# Cleanup the temporary tiles
	rm ${TILESTORAGEPATH}${CLEANFILENAME##*/}_tile_*.${FILEEXTENSION}
}

# Initiate preparatory checks
prepwork
# If the preparations worked, launch the main program
if (( VALIDJPEG )); then
	main
fi



###############################################################################
# EOF
###############################################################################
