#!/bin/bash

###############################################################################
#
# Image Analysis Script 0.1
#
# # Usage: bash analysis.sh /path/to/image-sample/folder
#
###############################################################################
#
# Tools that need to be pre-installed:
#
#	* ImageMagick >= v.6.6
#
# 	* JPEGOptim
#
#	* JPEGtran
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
# Configuration
###############################################################################

# Define 2 methods to compare to each other
# Currently possible values: lossless_jpegrescan, lossless_jpegtran, lossy_jpegoptim
METHODA="lossless_jpegrescan"
METHODB="lossless_jpegtran"

# Define which calculation shall be performed after the methods are done
# Currently possible values: calculate_filesize_gain
EVALUATION="calculate_filesize_gain"

# The toolbelt of currently available methods
# The Prefixes "lossless" / "lossy" should prevent comparing apples & oranges
# It does not require configuration, but it can take additional methods
declare -A METHODS=(
	[lossless_jpegtran]='jpegtran -copy none -optimize -progressive -outfile ${SOURCEDIR}"lossless_jpegtran_"${TIMESTAMP}/${file##*/} ${SOURCEDIR}${file##*/}'
	[lossless_jpegrescan]='jpegrescan -q -s ${SOURCEDIR}${file##*/} ${SOURCEDIR}"lossless_jpegrescan_"${TIMESTAMP}/${file##*/}'
	[lossy_jpegoptim]='jpegoptim -q -f -p -m85 --strip-all -d ${SOURCEDIR}"lossy_jpegoptim_"${TIMESTAMP} ${SOURCEDIR}${file##*/}'
)



###############################################################################
# PROGRAM
###############################################################################

# Wrapping the main program to allow defering function definitions
main() {
	create_output_folders
	process_sample_with_selected_methods
	${EVALUATION}
}



###############################################################################
# FUNCTIONS
###############################################################################

# Create seperate output folders for methods A+B for comparison
function create_output_folders {
	# Accept the source directory as a parameter
	SOURCEDIR="$1"
	# Set a human-readable timestamp
	TIMESTAMP=$(date +%Y%m%d_%H%M%S)
	# Create the directories to store results in, labeled by method + timestamp
	DIRECTORYA=${SOURCEDIR}${METHODA}"_"${TIMESTAMP}
	DIRECTORYB=${SOURCEDIR}${METHODB}"_"${TIMESTAMP}
	mkdir ${DIRECTORYA} ${DIRECTORYB}
}

# Run the 2 user-selected methods on the sample
function process_sample_with_selected_methods {
	IMAGESTOPROCESS=($(find . -maxdepth 1 -iregex ".*.jpe*g"))
	for((i=0;i<${#IMAGESTOPROCESS[@]};i++)); do
		file="${IMAGESTOPROCESS[$i]}"
		(eval "${METHODS[$METHODA]}")
		(eval "${METHODS[$METHODB]}")
		echo "Processed $((${i} + 1))/${#IMAGESTOPROCESS[@]} images ..."
	done
}

# Evaluation of filesize gains by compression methods
function calculate_filesize_gain {
	# Measure the filesize of each output directory
	SAMPLEASIZE=$(find ${DIRECTORYA}/. -maxdepth 1 -iregex ".*.jpe*g" -print0 | du --files0-from=- -c | tail -n1  | awk {'print $1'})
	SAMPLEBSIZE=$(find ${DIRECTORYB}/. -maxdepth 1 -iregex ".*.jpe*g" -print0 | du --files0-from=- -c | tail -n1  | awk {'print $1'})
	# Calculate the relative difference of directory sizes in percent
	SAMPLEASIZEONEPERCENT=$(echo "scale=4; ${SAMPLEASIZE}/100" | bc)
	GAINEDPERCENTAGE=$(echo "scale=1; 100-${SAMPLEBSIZE}/${SAMPLEASIZEONEPERCENT}" | bc)
	# Give appropriate human-readable output according to the result
	if [ 1 -eq $(echo "${GAINEDPERCENTAGE} > 0" | bc) ]
	then  
		echo "Ouch! ${METHODA} is ${GAINEDPERCENTAGE}% less efficient than ${METHODB}"
	else
		echo "Yeah! ${METHODA} is ${GAINEDPERCENTAGE#?}% more efficient than ${METHODB}"
	fi
}


# Finally, launch the main program now that everything else is defined
main



###############################################################################
# EOF
###############################################################################
