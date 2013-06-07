#!/bin/bash

###############################################################################
#
# Image Analysis Script 0.2
#
# # Usage: bash analysis.sh /path/to/image-sample/folder/
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

# Master switch!
# Set this to "analyse" to only run an analysis function on an existing sample
# or set to "compare" to run comparison tests which will result in processed
# data sets. Make sure that you select your desired evalution accordingly 
# Possible values: compare, analyse
PROCESS="analyse"

# Define 2 methods to compare to each other
# This is only used if $PROCESS is set to "compare"
# Currently possible values, sorted by type: 
#
# lossless_jpegrescan
# lossless_jpegtran
#
# lossy_jpegoptim
#
COMPARE_METHODA="lossless_jpegrescan"
COMPARE_METHODB="lossless_jpegtran"

# The toolbelt of currently available methods
# The Prefixes "lossless" / "lossy" should prevent comparing apples & oranges
# It does NOT REQUIRE configuration, but you can add more methods
declare -A METHODS=(
	[lossless_jpegtran]='jpegtran -copy none -optimize -progressive -outfile ${SOURCEDIR}"lossless_jpegtran_"${TIMESTAMP}/${file##*/} ${SOURCEDIR}${file##*/}'
	[lossless_jpegrescan]='jpegrescan -q -s ${SOURCEDIR}${file##*/} ${SOURCEDIR}"lossless_jpegrescan_"${TIMESTAMP}/${file##*/}'
	[lossy_jpegoptim]='jpegoptim -q -f -p -m85 --strip-all -d ${SOURCEDIR}"lossy_jpegoptim_"${TIMESTAMP} ${SOURCEDIR}${file##*/}'
)

# Define which evaluation shall be performed
# Please make sure that you have selected an "analyse_" evalution if
# you set $PROCESS to "analyse" or vice versa for "compare"
# 
# "analyse" processes will output results in a .txt file prefixed "analysis_"
#
# Currently possible values, grouped by methods "compare" and "analyse": 
#
# compare_filesize_gain
# 
# analyse_quality
# analyse_progressive_jpeg
#
EVALUATION="analyse_progressive_jpeg"

# Accept the source directory as a parameter
# Does not require manual configuration if the script is invoked correctly
SOURCEDIR="$1"

# Set a human-readable timestamp for inclusion in directory names etc.
# Does not require manual configuration unless you want to disable it
TIMESTAMP=$(date +%Y%m%d_%H%M%S)



###############################################################################
# PROGRAM
###############################################################################

# Wrapping the main program to allow defering function definitions
main() {
	if [ "$PROCESS" == "compare" ] ; then
		create_output_folders
		process_sample_with_selected_methods
	fi
	${EVALUATION}
}



###############################################################################
# FUNCTIONS
###############################################################################

# Create seperate output folders for methods A+B for comparison
function create_output_folders {
	# Create the directories to store results in, labeled by method + timestamp
	DIRECTORYA=${SOURCEDIR}${COMPARE_METHODA}"_"${TIMESTAMP}
	DIRECTORYB=${SOURCEDIR}${COMPARE_METHODB}"_"${TIMESTAMP}
	mkdir ${DIRECTORYA} ${DIRECTORYB}
}

# Run the 2 user-selected methods on the sample
function process_sample_with_selected_methods {
	IMAGESTOPROCESS=($(find ${SOURCEDIR} -maxdepth 1 -iregex ".*.jpe*g"))
	for((i=0;i<${#IMAGESTOPROCESS[@]};i++)); do
		file="${IMAGESTOPROCESS[$i]}"
		(eval "${METHODS[$COMPARE_METHODA]}")
		(eval "${METHODS[$COMPARE_METHODB]}")
		echo "Processed $((${i} + 1))/${#IMAGESTOPROCESS[@]} images ..."
	done
}

# Evaluation of filesize gains by compression methods
function compare_filesize_gain {
	# Measure the filesize of each output directory
	SAMPLEASIZE=$(find ${DIRECTORYA}/. -maxdepth 1 -iregex ".*.jpe*g" -print0 | du --files0-from=- -c | tail -n1  | awk {'print $1'})
	SAMPLEBSIZE=$(find ${DIRECTORYB}/. -maxdepth 1 -iregex ".*.jpe*g" -print0 | du --files0-from=- -c | tail -n1  | awk {'print $1'})
	# Calculate the relative difference of directory sizes in percent
	SAMPLEASIZEONEPERCENT=$(echo "scale=4; ${SAMPLEASIZE}/100" | bc)
	GAINEDPERCENTAGE=$(echo "scale=1; 100-${SAMPLEBSIZE}/${SAMPLEASIZEONEPERCENT}" | bc)
	# Give appropriate human-readable output according to the result
	if [ 1 -eq $(echo "${GAINEDPERCENTAGE} > 0" | bc) ]
	then  
		echo "Ouch! ${COMPARE_METHODA} is ${GAINEDPERCENTAGE}% less efficient than ${COMPARE_METHODB}"
	else
		echo "Yeah! ${COMPARE_METHODA} is ${GAINEDPERCENTAGE#?}% more efficient than ${COMPARE_METHODB}"
	fi
}

# Read JPEG Quality settings via ImageMagick's identify and store results for Mean, Avarage, Min+Max in a file
function analyse_quality {
	IMAGESTOPROCESS=($(find ${SOURCEDIR} -maxdepth 1 -iregex ".*.jpe*g"))
	for((i=0;i<${#IMAGESTOPROCESS[@]};i++)); do
		# Retrieve the image quality as an integer via ImageMagick's identify
		echo $(identify -quiet -format "%Q" "${IMAGESTOPROCESS[$i]}")
	done >> ${SOURCEDIR}quality_${TIMESTAMP}.txt
	# Sort the values by natural sort
	sort -n -o ${SOURCEDIR}quality_sorted_${TIMESTAMP}.txt ${SOURCEDIR}quality_${TIMESTAMP}.txt
	# Cleanup
	rm ${SOURCEDIR}quality_${TIMESTAMP}.txt
	# Remove all empty lines caused by identify being unable to read from damaged image files
	sed '/^$/d' ${SOURCEDIR}quality_sorted_${TIMESTAMP}.txt > ${SOURCEDIR}quality_sorted_cleaned_${TIMESTAMP}.txt
	# Cleanup
	rm ${SOURCEDIR}quality_sorted_${TIMESTAMP}.txt
	# Retrieve final sample size
	wc -l ${SOURCEDIR}quality_sorted_cleaned_${TIMESTAMP}.txt | awk '{print "Sample size = " $1}'  >> ${SOURCEDIR}analysis_quality_results.txt
	# Calculate Mean
	awk '{a[i++]=$1;} END {x=int((i+1)/2); if (x < (i+1)/2) print "Mean = "(a[x-1]+a[x])/2; else print "Mean = "a[x-1];}' ${SOURCEDIR}quality_sorted_cleaned_${TIMESTAMP}.txt >> ${SOURCEDIR}analysis_quality_results.txt
	# Calculate Average
	awk '{total+=$1; count+=1} END {print "Average = "total/count}' ${SOURCEDIR}quality_sorted_cleaned_${TIMESTAMP}.txt >> ${SOURCEDIR}analysis_quality_results.txt
	# Find Minimum
	awk '{if(min==""){min=max=$1}; if($1<min) {min=$1};} END {print "Minimal = "min}' ${SOURCEDIR}quality_sorted_cleaned_${TIMESTAMP}.txt >> ${SOURCEDIR}analysis_quality_results.txt
	# Find Maximum
	awk '{if(max==""){max=$1}; if($1>max) {max=$1};} END {print "Maximum = "max}' ${SOURCEDIR}quality_sorted_cleaned_${TIMESTAMP}.txt >> ${SOURCEDIR}analysis_quality_results.txt
	# Cleanup
	rm ${SOURCEDIR}quality_sorted_cleaned_${TIMESTAMP}.txt
}

# Use ImageMagick's identify to test for progressive JPG
function analyse_progressive_jpeg {
	IMAGESTOPROCESS=($(find ${SOURCEDIR} -maxdepth 1 -iregex ".*.jpe*g"))
	PROGRESSIVE=0
	TOTALCOUNT=0
	for((i=0;i<${#IMAGESTOPROCESS[@]};i++)); do
		# Returns "JPEG", "None" or an error if the file is unreadable by IM
		JPEGPROGRESSIVESTATE=$(identify -verbose "${IMAGESTOPROCESS[$i]}" | grep Interlace | awk {'print $2'})
		# If it returns "JPEG", the current JPG is saved as progressive, thus increment both counters
		if [ "$JPEGPROGRESSIVESTATE" == "JPEG" ] ; then
			PROGRESSIVE=$((PROGRESSIVE + 1))
			TOTALCOUNT=$((TOTALCOUNT + 1))
		# In case it returns "None", only increment the total count
		# This prevents counting defective files as part of the total count - we can't rely on IMAGESTOPROCESS[@]
		elif [ "$JPEGPROGRESSIVESTATE" == "None" ] ; then
			TOTALCOUNT=$((TOTALCOUNT + 1))
		fi
	done
	# Calculate percentage of progressive JPEGs
	TOTALCOUNTONEPERCENT=$(echo "scale=4; ${TOTALCOUNT}/100" | bc)
	PROGRESSIVEJPEGPERCENTAGE=$(echo "scale=1; ${PROGRESSIVE}/${TOTALCOUNTONEPERCENT}" | bc)
	# Save results to output file
	echo "Total JPEG sample size: ${TOTALCOUNT}" >> ${SOURCEDIR}analysis_progressive_jpeg_results.txt
	echo "Progressive JPEGs within sample: ${PROGRESSIVE}" >> ${SOURCEDIR}analysis_progressive_jpeg_results.txt
	echo "Percentage of progressive JPEGs within sample: ${PROGRESSIVEJPEGPERCENTAGE}%" >> ${SOURCEDIR}analysis_progressive_jpeg_results.txt
}

# Finally, launch the main program now that everything else is defined
main



###############################################################################
# EOF
###############################################################################
