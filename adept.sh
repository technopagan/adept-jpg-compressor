#!/bin/bash

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
# Configuration Parameters
###############################################################################

# Accept the jpg filename as a parameter
FILE="$1"

# Verbose mode for tweaking settings and debugging 
# Value: 0/1, because Bash does not have boolean true/false 
VERBOSEMODE=0

# Control noise threshold for tiles. Higher threshold leads to more tiles being marked as compressable at the cost of image quality
# Deafult: 0.175% - only raise in small steps, e.g. 0.333% or 0.5%
BLACKWHITETHRESHOLD="0.333%"

# Default JPG quality setting, either inherited or defined as an integer of 0-100
# Default: inherit
DEFAULTCOMPRESSIONRATE="inherit"

# JPEG quality setting for areas of the image deemed suitable for high compression in an integer of 0-100
# Default: 66
HIGHCOMPRESSIONRATE="66"

# Square dimensions for all temporary tiles. Only use multiples of 8 (8/16/32/64/128/256)
# Default: 64 - The tile size heavily influences runtime performance 
TILEWIDTHANDHEIGHT="64"

# Storage location for all temporary files during runtime
# Use locations like /dev/shm (/run/shm/ in Ubuntu) to save files in Shared Memory Space (RAM) to avoid disk i/o troubles
TILESTORAGEPATH="/dev/shm/"

# Suffix string to attach to the output JPG filename, e.g. '_adept_compress'
# If deliberatly set empty (''), the input JPG will be replaced with the new compressed JPG created by this script
OUTPUTFILESUFFIX="_adept_compress"



###############################################################################
# PROGRAM
###############################################################################

# Strip path directories and extension to retrieve a clean filename

if (( VERBOSEMODE )); then
	FILESIZEORIGINAL=`stat -c %s $1`
	printf "\nWorking on JPG ${1}, ${FILESIZEORIGINAL} bytes\n"
	read -p "Press [Enter] to continue"
fi

CLEANFILENAME=${FILE%.jpg}


# If $DEFAULTCOMPRESSIONRATE is set to "inherit", discover the input JPG quality 

if [ "$DEFAULTCOMPRESSIONRATE" == "inherit" ] ; then
	DEFAULTCOMPRESSIONRATE=`identify -format "%Q" "${1}"`
fi


# Slice the input image into equally sized tiles

if (( VERBOSEMODE )); then
	printf "\nSplitting the image into equally sized tiles and saving them to ${TILESTORAGEPATH}\n"
	read -p "Press [Enter] to continue"
fi

convert "$FILE" -strip -quality "${DEFAULTCOMPRESSIONRATE}" -crop "${TILEWIDTHANDHEIGHT}"x"${TILEWIDTHANDHEIGHT}" -set filename:tile "%[fx:page.y/${TILEWIDTHANDHEIGHT}+1]x%[fx:page.x/${TILEWIDTHANDHEIGHT}+1]" +repage +adjoin "${TILESTORAGEPATH}${CLEANFILENAME##*/}_tile_%[filename:tile].jpg"


# Fill an array with the paths+filenames of all the tiles we have just sliced so that we can work on each of them
# Also resort the freshly filled array from ASCII sort order to natural sort order so that filename_100 does not get processed before filename_1

if (( VERBOSEMODE )); then
	printf "\nFilling an array with the image tiles to iterate upon\n"
	read -p "Press [Enter] to continue"
fi

TILES=(${TILESTORAGEPATH}${CLEANFILENAME##*/}_tile_*.jpg)
TILES=($(printf '%s\n' "${TILES[@]}"|sort -V))

if (( VERBOSEMODE )); then
	printf "\nThe filled and sorted array of tiles:\n\n${TILES[*]}\n\n"
	read -p "Press [Enter] to continue"
fi


# Iterate over every created tile we have listed in our array
for((i=0;i<${#TILES[@]};i++))
do

	# Run an all-directional Sobel edge detection on the tile to discover high contrast borders
	# These borders are areas JPG compression always has troubles with - so we will tread carefully if we detect them
	# Then convert the Sobel result to a 2-color black+white image (channel ALL enables us to not lose information in the process) so that we can easily count the pixels
	# The Threshold parameter is a basic noise filter - anything below it gets dropped so that our b/w-image is actually useful and not just pixelated noise
	# Then we run identify on the 2-color limited palette PNG8 to retrieve the mean for the gray channel
	# The result will be a decimal number (or zero) by which we can judge the visible object complexity in the current tile
	
	if (( VERBOSEMODE )); then
		printf "\nCreate an all-directional Sobel version of ${TILES[$i]} and limit its palette to 2-color black and white.\n"
		read -p "Press [Enter] to continue"
	fi	

	CLEANTILENAME=${TILES[$i]%.jpg}
	convert ${TILES[$i]} -define convolve:scale='!' -define morphology:compose=Lighten -morphology Convolve 'Sobel:>' "${CLEANTILENAME}_sobel.jpg"
	convert "${CLEANTILENAME}_sobel.jpg" -channel All -random-threshold "${BLACKWHITETHRESHOLD}" "${CLEANTILENAME}_sobel_bw.png"
	BWMEDIAN=`identify -channel Gray -format "%[fx:255*mean]" "${CLEANTILENAME}_sobel_bw.png"`

	if (( VERBOSEMODE )); then
		IDENTIFYOUTPUT=`identify -verbose "${CLEANTILENAME}_sobel_bw.png"`
		printf "\nRetrieving identify information for the current tile:\n\n${IDENTIFYOUTPUT}\n\nUsing this information to retrieve the gray channel mean: ${BWMEDIAN}\n"
		read -p "Press [Enter] to continue"
	fi	
	
	# If the gray channel median is below a defined threshold, the visible area in the current tile is very likely simple & rather monotonous and can safely be exposed to a higher compression rate 
	# Untouched JPGs simply stay at the defined default quality setting ($DEFAULTCOMPRESSIONRATE)
	if (( $(echo "$BWMEDIAN < 0.825" | bc -l) )); then
		
		if (( VERBOSEMODE )); then
			printf "\nThe contents of tile ${TILES[$i]} appear to have very little complexity, so we are compressing it more heavily to reduce filesize.\n"
			read -p "Press [Enter] to continue"
		fi

		jpegoptim --max=${HIGHCOMPRESSIONRATE} -t -v --strip-all ${TILES[$i]} >/dev/null 2>/dev/null

	fi

done

# First thing after the for-loop: cleanup the temporary Sobel tiles so they don't get mixed up in our montage reassembly and don't occupy Shared Memory any longer than necessary

if (( VERBOSEMODE )); then
	printf "\nDeleting the temporary files created by running the Sobel edge detector\n"
	read -p "Press [Enter] to continue"
fi

rm ${TILESTORAGEPATH}${CLEANFILENAME##*/}_tile_*sobel*


# For the reassembly of the image, we need the number of columns + rows of tiles that were created
# Let's begin by fetching image dimensions

if (( VERBOSEMODE )); then
	printf "\nCalculating image and tile dimensions required for successfuly reassembly\n"
	read -p "Press [Enter] to continue"
fi

IMAGEHEIGHT=`identify -format '%h' ${FILE}`
IMAGEWIDTH=`identify -format '%w' ${FILE}`

# Divide the width+height by tile-size using bc because Bash cannot handle floating point calculations

TILEROWSDECIMAL=`echo "scale=4; ${IMAGEHEIGHT}/${TILEWIDTHANDHEIGHT}" | bc`
TILECOLUMNSDECIMAL=`echo "scale=4; ${IMAGEWIDTH}/${TILEWIDTHANDHEIGHT}" | bc`

# Make use of Bash's behaviour of rounding down to see if we're tile-number = integer + 1

TILEROWSROUNDEDDOWN=`echo $((${IMAGEHEIGHT}/${TILEWIDTHANDHEIGHT}))`
TILECOLUMNSROUNDEDDOWN=`echo $((${IMAGEWIDTH}/${TILEWIDTHANDHEIGHT}))`

# For both rows+columns, check if we need to +1 our integer because the decimal is larger than it

if (( $(echo "$TILEROWSDECIMAL > $TILEROWSROUNDEDDOWN" | bc -l) )); then
	TILEROWS=`echo $((${TILEROWSROUNDEDDOWN}+1))`
else
	TILEROWS=${TILEROWSROUNDEDDOWN}
fi

if (( $(echo "$TILECOLUMNSDECIMAL > $TILECOLUMNSROUNDEDDOWN" | bc -l) )); then
	TILECOLUMNS=`echo $((${TILECOLUMNSROUNDEDDOWN}+1))`
else
	TILECOLUMNS=${TILECOLUMNSROUNDEDDOWN}
fi

if (( VERBOSEMODE )); then
	printf "\nThe original image has a width of ${IMAGEWIDTH}px and height of ${IMAGEHEIGHT}px, resulting in ${TILECOLUMNS} columns and ${TILEROWS} rows of tiles for reassembly\n"
	read -p "Press [Enter] to continue"
fi


# Now that we know our number of rows+columns, we can use montage to recombine the - now partially compressed - tiles into one coherant JPG
# We're piping the list of filenames to process by montage to "sort -V" to achieve natural sorting so that tilename_2_10.jpg actually is processed after tilename_2_9.jpg and not before tilename_2_1.jpg - otherwise the recombined image would be messed up 

if (( VERBOSEMODE )); then
	printf "\nReassembling all processed tiles into one coherent image named ${CLEANFILENAME##*/}${OUTPUTFILESUFFIX}.jpg.\n"
	read -p "Press [Enter] to continue"
fi

montage -strip -quality "${DEFAULTCOMPRESSIONRATE}" -mode concatenate -tile "${TILECOLUMNS}x${TILEROWS}" $(ls "${TILESTORAGEPATH}${CLEANFILENAME##*/}"_tile_*.jpg | sort -V) "${CLEANFILENAME##*/}${OUTPUTFILESUFFIX}".jpg


# During montage reassembly, the resulting image received bytes of padding due to the way the JPEG compression algorithm works on tiles not sized as a multiple of 8   
# So we run jpegrescan on the final image to losslessly remove this padding and make the output JPG progressive

if (( VERBOSEMODE )); then
	printf "\nRunning jpegrescan to losslessly remove bytesize padding, caused by processing cutoff tiles not sized as a multiple of 8.\n"
	read -p "Press [Enter] to continue"
fi

jpegrescan -s "${CLEANFILENAME##*/}${OUTPUTFILESUFFIX}".jpg "${CLEANFILENAME##*/}${OUTPUTFILESUFFIX}".jpg  >/dev/null 2>/dev/null


# Cleanup the temporary tiles

if (( VERBOSEMODE )); then
	printf "\nDeleting all remaining tiles created during runtime.\n"
	read -p "Press [Enter] to continue"
fi

rm ${TILESTORAGEPATH}${CLEANFILENAME##*/}_tile_*.jpg


# Calculate compression winnings in percent

if (( VERBOSEMODE )); then
	FILESIZECOMPRESSED=`stat -c %s ${CLEANFILENAME##*/}${OUTPUTFILESUFFIX}.jpg`
	FILESIZEORIGINALONEPERCENT=`printf %s $((${FILESIZEORIGINAL}/100))`
	FILESIZEWIN=`printf %s $((${FILESIZECOMPRESSED}/${FILESIZEORIGINALONEPERCENT}))`
	printf "\nCompressed file is ${FILESIZEWIN} percent of original filesize.\n\nMy work here is done. Goodbye!\n\n"
fi



###############################################################################
# EOF
###############################################################################
