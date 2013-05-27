#!/bin/bash

###############################################################################
#
# Bash script to retrieve a statistically representative number of images from
# sites indexed by HTTP Archive (http://httparchive.org) for analysis
#
# Usage: bash imageanalysis.sh http://www.archive.org/download/httparchive_downloads/httparchive_May_15_2013_requests.csv.gz
# 
###############################################################################
# Tools that need to be pre-installed:
#
#	* ImageMagick >= v.6.6
#
# 	* Randomize Lines >= v.0.2.7
# 
# 	* cURL >= v.7.x
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
REQUESTSCSVURL="$1"

# Which type of images to fetch: JPG, PNG, GIF or ALL
# We cannot test for WEBP with HTTP Archive CSV sources because its UA is IE
# which does not support WEBP
# Default: ALL
IMAGETYPE="JPG"


# Number of images to be analysed. Higher means longer processing time.
# Default: 32768
SAMPLESIZE=32



###############################################################################
# PROGRAM
###############################################################################

# Download the chosen gzipped CSV from HTTP Archive
curl -L -o requests.gz "$REQUESTSCSVURL"

# Extract the gzipped download, resulting in a >24GB file called requests.txt
gunzip requests.gz

# Cleanup
rm requests.gz

# The CSV "requests.txt" contains the entire HTTP request output
# So we only grab the sixth columnn of each row & write them to a new file:
cat requests.txt | cut -d \, -f 6 > all_urls.txt

# Cleanup
rm requests.txt

# Retrieve all image-urls from the list of all urls according to the desired
# image types to be downloaded
if [ "$IMAGETYPE" == "ALL" ] ; then

	grep -ioP '(http(.*)\.(?:jpe?g|png|webp|gif))' all_urls.txt > image_urls.txt

elif [ "$IMAGETYPE" == "JPG" ] ; then

	grep -ioP '(http(.*)\.(?:jpe?g))' all_urls.txt > image_urls.txt

elif [ "$IMAGETYPE" == "PNG" ] ; then

	grep -ioP '(http(.*)\.(?:png))' all_urls.txt > image_urls.txt

elif [ "$IMAGETYPE" == "GIF" ] ; then

	grep -ioP '(http(.*)\.(?:gif))' all_urls.txt > image_urls.txt

else
	# Fallback: if $IMAGETYPE is misconfigured, also get all image types
	grep -ioP '(http(.*)\.(?:jpe?g|png|gif))' all_urls.txt > image_urls.txt

fi

# Cleanup
rm all_urls.txt

# Use "randomize lines" from Universe in Debian to randomize the order of 
# all image urls very fast & memory efficient
rl -o image_urls_random_order.txt image_urls.txt

# Cleanup
rm image_urls.txt

# Make sure not attempt to retrieve a sample larger than the entire dataset  
RANGE=$(wc -l image_urls.txt | awk {'print $1'})
if [ "$SAMPLESiZE" > "$RANGE" ] ; then
	SAMPLESIZE="$RANGE"
fi

# Extract the sample
sed "$SAMPLESIZE"q image_urls_random_order.txt > image_urls_sample.txt

# Fetch each image referenced by url in the sample
# using a subshell for wget so downloads run in paralell  
while read -r line
do
	(curl -L -o ${line##*/} "$line")
done < image_urls_sample.txt



###############################################################################
# EOF
###############################################################################
