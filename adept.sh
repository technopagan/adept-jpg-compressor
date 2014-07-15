#!/usr/bin/env bash

###############################################################################
#
# Bash script to automate adaptive JPEG compression using common CLI tools
#
# Usage: bash adept.sh /path/to/image.jpg
#
###############################################################################
#
# Brief overview of the mode of operation:
#
# The input JPG gets sliced into tiles, sized as a multiple of 8 due to the
# nature of JPG compression. The image is also run through a saliency
# detection algorithm and its resulting output further reduced to a
# 2-color black+white PNG.
#
# This bi-color PNG is ideal to measure tiles' gray channel mean value and use
# it as a single integer indicator to judge its perceivable complexity.
#
# Areas with low complexity contents are then exposed to heavier compression.
# At reassembly, this leads to savings in image byte size while maintaining
# good visual quality because no compression artifacts occur in areas of
# high-complexity or sharp contrasts.
#
###############################################################################
# Tools that need to be pre-installed:
#
#	* Maximum Symmetric Surround Saliency Algorithm Binary
#	 http://github.com/technopagan/mss-saliency
#
#	* ImageMagick >= v.6.6
#
#	* JPEGOptim
#
#	* JPEGRescan Perl Script for lossless JPG compression
#	 http://github.com/kud/jpegrescan
#
# Note: Additional tools are required to run Adept, such as "bc",
# "find", "rm" and Bash 3.x. As all of these tools are provided by lsbcore, core-utils
# or similar default packages, we can expect them to be always available.
#
###############################################################################
#
# This software is published under the BSD license 3.0
#
# Copyright (c) 2013-2014, Tobias Baldauf
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
# Default: 69
HIGHCOMPRESSIONRATE="69"

# Suffix string to attach to the output JPG filename, e.g. '_adept_compress'
# If deliberately set empty (''), the input JPG will be replaced with the new compressed JPG
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
# If the JPEG is in the same directory as Adept, empty the path variable
# Or if it is set, make sure the path has a trailing slash
if [ "$CLEANPATH" == "$FILE" ]; then
	CLEANPATH=""
else
	CLEANPATH="$CLEANPATH/"
fi

# Storage location for all temporary files during runtime
# Use locations like /dev/shm (/run/shm/ in Ubuntu) to save files in Shared Memory Space (RAM) to avoid disk i/o troubles
TILESTORAGEPATH="/dev/shm/"
# Check if the directory for temporary image storage during runtime actually exists (honoring symlinks)
# In case it does not, fall back to using "/tmp/" because it is very likely available on all Unix systems
if [ ! -d "$TILESTORAGEPATH" ]; then
	TILESTORAGEPATH="/tmp/"
fi

# Square dimensions for all temporary tiles. Tile size heavily influences compression efficiency at the cost of runtime performance
# E.g. a tile size of 8 yields maximum compression results while taking several minutes of runtime
# If you chose to manually adjust tile size, only use multiples of 8 (8/16/32/64/128/256)
# Default: autodetect
TILESIZE="autodetect"

# Set locales to C (raw uninterpreted byte sequence)
# to avoid Illegal byte sequence errors and invalid number errors
export LANG=C LC_NUMERIC=C LC_COLLATE=C



###############################################################################
# MAIN PROGRAM
###############################################################################

prepwork () {
	find_tool IDENTIFY_COMMAND identify
	find_tool CONVERT_COMMAND convert
	find_tool MONTAGE_COMMAND montage
	find_tool JPEGOPTIM_COMMAND jpegoptim
	find_tool JPEGRESCAN_COMMAND jpegrescan
	find_tool SALIENCYDETECTOR_COMMAND SaliencyDetector
	validate_image VALIDJPEG "${FILE}"
}

main () {
	find_image_dimension IMAGEWIDTH "${FILE}" 'w'
	find_image_dimension IMAGEHEIGHT "${FILE}" 'h'
	optimize_tile_size TILESIZE ${TILESIZE} ${IMAGEWIDTH} ${IMAGEHEIGHT}
	calculate_tile_count TILEROWS ${IMAGEHEIGHT} ${TILESIZE}
	calculate_tile_count TILECOLUMNS ${IMAGEWIDTH} ${TILESIZE}
	optimize_salient_regions_amount BLACKWHITETHRESHOLD "${FILE}"
	${SALIENCYDETECTOR_COMMAND} -q -L0 -U${BLACKWHITETHRESHOLD} "${FILE}" "${TILESTORAGEPATH}${CLEANFILENAME##*/}_saliency_bw.png"
	slice_image_to_ram "${FILE}" ${TILESIZE} ${TILESTORAGEPATH}
	estimate_content_complexity_and_compress
	reassemble_tiles_into_final_image
	compare_file_sizes
	cleanup
}



###############################################################################
# FUNCTIONS
###############################################################################

# Convert floats to integers
function floatToInt() {
    printf "%.0f\n" "$@"
}

# Get a file's size
function filesize () {
	# Define local variables to work with
	local __result=$1
	# Use GNU stat by default
	local __statcommand="stat -c '%s'"
	if [ ! $($__statcommand /dev/null >/dev/null 2>/dev/null) ]; then
		# If that doesn't work, use BSD stat
		local __statcommand="stat -f '%z'"
	fi
	# Return the result
	eval $__result=$($__statcommand "$2")
}

# Find the proper handle for the required command-line tool
# This function can take an optional third parameter when being called to manually define the path to the CLI tool
function find_tool () {
	# Define local variables to work with
	local __result=$1
	local __tool=$2
	local __customtoolpath=$3
	# Array of possible tool locations: name, name as ALL-CAPS, /usr/bin/name, /usr/local/bin/name and custom path
	local __possibletoollocations=(${__tool} /usr/bin/${__tool} /usr/local/bin/${__tool} ${__customtoolpath})
	# For each possible tool location, test if its actually available there
	for i in "${__possibletoollocations[@]}"; do
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
function validate_image () {
	# Define local variables to work with
	local __result=$1
	local __imagetovalidate=$2
	# If the script is called without an input file, explain how to use it
	# We don't "exit 1" here anymore because our unit tests source the script
	# and would abort if "exit 1" was called
	if [ ! -f "$__imagetovalidate" ]; then
		local __validationresult=0
		echo "Missing input JPEG. Usage: $0 /path/to/jpeg/image.jpg"
	else
		# Use IM identify to read the file magic of the input file to validate it's a JPEG
		local __filemagic=$(${IDENTIFY_COMMAND} -format %m "$__imagetovalidate")
		if [ "$__filemagic" == "JPEG" ] ; then
			# Set a switch that it is ok to work on the input file, launching the main function
			local __validationresult=1
		fi
	fi
	# Return the result
	eval $__result="'${__validationresult}'"
}

# Read width (%w) or height (%h) of the input image via IM identify
function find_image_dimension () {
	# Define local variables to work with
	local __result=$1
	local __imagetomeasure=$2
	local __dimensiontomeasure=$3
	# Read the width or height of the input image into a global variable
	local __imagedimension=$(${IDENTIFY_COMMAND} -format '%'${__dimensiontomeasure} ${__imagetomeasure})
	# Return the result
	eval $__result="'${__imagedimension}'"
}

# Tile size is the principal performance bottleneck for Adept, so it is important we pick an optimal tile size for the input image dimensions
# Also, the number of tiles to be recombined affects compression efficiency and salient areas within an image tend to have similar dimensional
# relations to total image size, so it makes sense to change tile size accordingly
function optimize_tile_size () {
	# Define local variables to work with
	local __result=$1
	local __optimaltilesize=$2
	local __currentimagewidth=$3
	local __currentimageheight=$4
	# The default "autodetect" setting causes Adept to find a suitable tile size according to image dimensions
	if [ "$TILESIZE" == "autodetect" ] ; then
		# Pick the smaller of the two dimensions of the image as the decisive integer for tile size
		local __decisivedimension=${__currentimageheight}
		if (( $IMAGEWIDTH < $__decisivedimension )); then
			__decisivedimension=${__currentimagewidth}
		fi
		# For a series of sensible steps, change the tile size accordingly
		if (( $__decisivedimension <= 128 )); then
			__optimaltilesize="8"
		elif (( $__decisivedimension >= 129 )) && (( $__decisivedimension <= 256 )); then
			__optimaltilesize="16"
		elif (( $__decisivedimension >= 257 )) && (( $__decisivedimension <= 512 )); then
			__optimaltilesize="32"
		elif (( $__decisivedimension >= 513 )) && (( $__decisivedimension <= 1024 )); then
			__optimaltilesize="64"
		elif (( $__decisivedimension >= 1025 )) && (( $__decisivedimension <= 2560 )); then
			__optimaltilesize="128"
		elif (( $__decisivedimension >= 2561 )); then
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

function optimize_salient_regions_amount () {
	# Define local variables to work with
	local __result=$1
	local __imagetomeasure=$2
	local __lower_bound="0"
	local __upper_bound="100"
	local __current_threshold=$(( $__upper_bound/2 ))
	local __mean_graychannel="0"
	# Run the saliency detector function to retrieve the Median gray channel
	calculate_salient_regions_amount __mean_graychannel "${__imagetomeasure}" ${__upper_bound}

	__mean_graychannel=$(floatToInt $__mean_graychannel)

	# If we didn't hit the sweet spot on our initial run, keep homing in on the ideal threshold value using binary search
	while ( (( $__mean_graychannel > 40 )) || (( $__mean_graychannel < 20  )) ) && (( $__lower_bound < $__upper_bound-1 )); do
		# If the Median is too low, reduce the upper threshold value to get more white pixels
		if (( $__mean_graychannel < 20 )); then
			__upper_bound=${__current_threshold}
		# Else if the Median is too high, raise the threshold to get fewer white pixels
		elif (( $__mean_graychannel > 40 )); then
			__lower_bound=${__current_threshold}
		fi
		# Calculate the new middle threshold
		__current_threshold=$(( ($__upper_bound-$__lower_bound)/2+$__lower_bound ))
		# Rerun the saliency detector with a better estimated threshold value
		calculate_salient_regions_amount __mean_graychannel "${__imagetomeasure}" ${__current_threshold}

		__mean_graychannel=$(floatToInt $__mean_graychannel)
	done
	# Return result
	eval $__result="'${__current_threshold}'"
}

# Measure the black/white median of a saliency mapped image to use it as an indicator for successful saliency mapped contents
function calculate_salient_regions_amount () {
	# Define local variables to work with
	local __result=$1
	local __imagetomeasure=$2
	local __threshold=$3
	# Use the MSS Saliency Detector with custom thresholds to generate a black+white salient map of an input image
	# Then use the gray channel's mean as a single indicator to judge how much of the image's contents have been marked as salient
	local __salient_amount=$(${SALIENCYDETECTOR_COMMAND} -q -L0 -U${__threshold} "${__imagetomeasure}" "png:-" | ${IDENTIFY_COMMAND} -channel Gray -format "%[fx:255*mean]" -)
	# Return result
	eval $__result="'${__salient_amount}'"
}

# Slice the input image into equally sized tiles
function slice_image_to_ram () {
	# Define local variables to work with
	local __filetoprocess=$1
	local __currenttilesize=$2
	local __currenttilestoragepath=$3
	# If $DEFAULTCOMPRESSIONRATE is set to "inherit", discover the input JPG quality
	if [ "$DEFAULTCOMPRESSIONRATE" == "inherit" ] ; then
		DEFAULTCOMPRESSIONRATE=$(${IDENTIFY_COMMAND} -format "%Q" ${__filetoprocess})
	fi
	${CONVERT_COMMAND} "$__filetoprocess" -strip -quality "${DEFAULTCOMPRESSIONRATE}" -define jpeg:dct-method=float -crop "${__currenttilesize}"x"${__currenttilesize}" +repage +adjoin "${__currenttilestoragepath}tile_tmp_%06d_${CLEANFILENAME##*/}.${FILEEXTENSION}"
}

# For each tile, test if it is suitable for higher compression and if so, proceed
function estimate_content_complexity_and_compress () {
	# Set up a counter so we keep track of the full name of the current temporary tile to work on
	local __currenttilecount=0
	# Let's create a walker that iterates over the sobeled and b/w reduced full size image
	# This way, the edge detection happens only in memory and does not need additional tiles to be created on the filesystem
	# The walker inputs X+Y coordinates and only analyses a single tile's size on that spot within the image
	# The exception to this being when we are close to the image's end and we have to reduce tile size to whatever is left vertically or horizontally
	for((y=0;y<$TILEROWS;y++)) ; do
		for((x=0;x<$TILECOLUMNS;x++)) ; do
			# Reset tile dimensions for each run because we need to check them anew each time
			local __currenttileheight=${TILESIZE}
			local __currenttilewidth=${TILESIZE}
			# Count up the processed tile number and setting it to Base10 because we will be padding it with leading zeros and Bash would interpret the integer as Base8 per default
			__currenttilecount=$(( 10#$__currenttilecount + 1 ))
			# Prepend leading zeros to the counter so the integer matches the numbers handed out to the filename by ImageMagick
			__currenttilecount=$(printf "%06d" $__currenttilecount);
			# If we are nearing the end of the image height, reduce tile size to whatever is left vertically
			if (( $y + 1 == $TILEROWS )) && (( $TILEROWS * $__currenttileheight > $IMAGEHEIGHT )); then
				__currenttileheight=$(( (($y+1)*$TILESIZE) - $IMAGEHEIGHT ))
				__currenttilerow=$(( $y+1 ))
			fi
			# And if we are nearing the end of the image width, reduce tile size to whatever is left horizontally
			if (( $x + 1 == $TILECOLUMNS )) && (( $TILECOLUMNS * $__currenttilewidth > $IMAGEWIDTH )); then
				__currenttilewidth=$(( (($x+1)*$TILESIZE) - $IMAGEWIDTH ))
				__currenttilecolumn=$(( $x+1 ))
			fi
			# Run identify on the 2-color limited palette PNG8 to retrieve the mean for the gray channel
			# In this case we are using coordinates and dynamic tile sizes according to the walker logic we have created in order to dynamically view a specific image area without creating actual tiles for it
			# The result will be a decimal number (or zero) by which we can judge the visible object complexity in the current tile
			local __currentbwmedian=$(identify -size "${IMAGEWIDTH}"x"${IMAGEHEIGHT}" -channel Gray -format "%[fx:255*mean]" "${TILESTORAGEPATH}${CLEANFILENAME##*/}_saliency_bw.png["${__currenttilewidth}"x"${__currenttileheight}"+$(echo $((${x}*${__currenttilewidth})))+$(echo $((${y}*${__currenttileheight})))]")
			# If the gray channel median is below a defined threshold, the visible area in the current tile is very likely simple & rather monotonous and can safely be exposed to a higher compression rate
			# Untouched JPGs simply stay at the defined default quality setting ($DEFAULTCOMPRESSIONRATE)
			if (( $(echo "$__currentbwmedian < 0.825" | bc) )); then
				# We experimented with blurring/smoothing of tiles here to enhance JPEG compression, but results were insignificant
				${JPEGOPTIM_COMMAND} --max=${HIGHCOMPRESSIONRATE} --strip-all --strip-iptc --strip-icc "${TILESTORAGEPATH}"tile_tmp_"${__currenttilecount}"_"${CLEANFILENAME##*/}"."${FILEEXTENSION}" >/dev/null 2>/dev/null
			fi
		done
	done
}

# For the reassembly of the image, we need the count of rows and columns of tiles that were created
function calculate_tile_count () {
	# Define local variables to work with
	local __result=$1
	local __currentimagedimension=$2
	local __currenttilesize=$3
	# Make use of Bash's behaviour of rounding down to see if we're tilecount = integer + 1
	local __tilecountroundeddown=$(( $__currentimagedimension / $__currenttilesize ))
	# Check if we need to +1 our integer because the decimal is larger than the integer
	if (( $__currenttilesize * $__tilecountroundeddown < $__currentimagedimension )); then
		local __tilecount=$(( $__tilecountroundeddown + 1 ))
	else
		local __tilecount=${__tilecountroundeddown}
	fi
	# Return result
	eval $__result="'${__tilecount}'"
}

# Now that we know the number of rows+columns, we use montage to recombine the now partially compressed tiles into a new coherent JPEG image
function reassemble_tiles_into_final_image () {
	# Use montage to reassemble the individual, partially optimized tiles into a new consistent JPEG image
	${MONTAGE_COMMAND} -quiet -strip -quality "${DEFAULTCOMPRESSIONRATE}" -mode concatenate -tile "${TILECOLUMNS}x${TILEROWS}" $(find "${TILESTORAGEPATH}" -maxdepth 1 -type f -name "tile_tmp_*_${CLEANFILENAME##*/}.${FILEEXTENSION}" | sort) "${TILESTORAGEPATH}${CLEANFILENAME##*/}${OUTPUTFILESUFFIX}".${FILEEXTENSION} >/dev/null 2>/dev/null

	# During montage reassembly, the resulting image received bytes of padding due to the way the JPEG compression algorithm works on tiles not sized as a multiple of 8
	# So we run jpegrescan on the final image to losslessly remove this padding and make the output JPG progressive
	${JPEGRESCAN_COMMAND} -q -i "${TILESTORAGEPATH}${CLEANFILENAME##*/}${OUTPUTFILESUFFIX}".${FILEEXTENSION} "${TILESTORAGEPATH}${CLEANFILENAME##*/}${OUTPUTFILESUFFIX}".${FILEEXTENSION}
}

function compare_file_sizes () {
	# Define local variables to work with
	local __tmpfile="${TILESTORAGEPATH}${CLEANFILENAME##*/}${OUTPUTFILESUFFIX}".${FILEEXTENSION}
	local __tmpfilesise=0
	local __originalfilesize=0
	# Get file sizes
	filesize __originalfilesize "$FILE"
	filesize __tmpfilesise "$__tmpfile"
	# Move image to final location if smaller
	if (( $__tmpfilesise < $__originalfilesize )); then
		move_final_image_into_place
	else
		echo "Output is larger than the original image. Nothing being done."
	fi
}

# Move the final image to the output destination
function move_final_image_into_place () {
	# The output destination file may already exist; overwrite if necessary 
	mv -f "${TILESTORAGEPATH}${CLEANFILENAME##*/}${OUTPUTFILESUFFIX}".${FILEEXTENSION} "${CLEANPATH}${CLEANFILENAME##*/}${OUTPUTFILESUFFIX}".${FILEEXTENSION} >/dev/null 2>/dev/null
}

# Cleanup temporary files
function cleanup () {
	# Define local variables to work with
	local __tmpfile="${TILESTORAGEPATH}${CLEANFILENAME##*/}${OUTPUTFILESUFFIX}".${FILEEXTENSION}
	# Remove temporary file, if it still exists
	if [ -e $__tmpfile ]; then
		rm $__tmpfile
	fi
	# Remove saliency map
	rm ${TILESTORAGEPATH}${CLEANFILENAME##*/}_saliency_bw.png
	# We are using find to circumvent issues on Kernel based shell limitations when iterating over a large number of files with rm
	find "${TILESTORAGEPATH}" -maxdepth 1 -type f -name "tile_tmp_*_${CLEANFILENAME##*/}.${FILEEXTENSION}" -exec rm {} \;
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
