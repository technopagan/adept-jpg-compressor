#!/bin/env bash

ADEPT="jpeg-adept.sh"

if ! which "$ADEPT" > /dev/null; then echo Please install $ADEPT in your path.; fi

usage() {
	echo "Usage: $0 [Options] PATH

Recursively compresses all the *.jpe?g files in PATH, 
saving the originals.

Options (and defaults):

	-d	max-depth (no max directory depth)
	-P	parallel (1)
	-n	max-count (no max # of filesinfinite)	
	-x	remove original images
  	-D	turn on debug mode	

The originals are saved as '_adept_save.jpg' files.

The flag file '_adept.flag' is created, so this program
can be run automatically.  Removal of this file will 
cause recompression of the compressed image.

-x is unsafe.  It's strongly recommended to actually look at 
the results for a while before removing the originals.   Also
JPEG compression is lossy.   You've been warned.
"
}


debug() {
	if [ $debug ]; then echo "$@" 1>&2; fi
}

compress() {
	local fil="$1"
	local bn="${fil%.*}"
	if [ "$fil" -nt "${bn}_adept_save.jpg" ]; then
		# newer than both?
		if [ "$fil" -nt "${bn}_adept_compress.jpg" ]; then
		if [ "$fil" -nt "${bn}_adept.flag" ]; then
			# this is a new file, so compress it
			echo + jpeg-adept.sh \"$fil\" 1>&2
			jpeg-adept.sh "$fil"
			rm -f "${bn}_adept.flag"
		fi
		fi

		# ok, we just compressed it
		if [ "${bn}_adept_compress.jpg" -nt "${bn}.jpg" ]; then
			# check to see if it's smaller
			local var1=$(stat -c%s "$fil")
			local var2=$(stat -c%s "${bn}_adept_compress.jpg")
			debug "$fil: $var1, compressed: $var2"
			if [ $var2 -lt $var1 ]; then
				# save original, and 
				if [ $rmorig ]; then
					debug "Destroying original '$fil'"
				else
					mv "$fil" "${bn}_adept_save.jpg"
				fi
				mv -f "${bn}_adept_compress.jpg" "$fil"
				echo "ok"> "${bn}_adept.flag"
			else
				echo "toobig"> "${bn}_adept.flag"
				unlink "${bn}_adept_compress.jpg"
			fi
		fi
	fi
}

debug=""
unset count pll depth fil rmorig
while getopts "Dxd:f:r:n:P:" optionName; do
case "$optionName" in
	P) pll="$OPTARG";;
	d) depth="$OPTARG";;
	D) debug=1;;
	n) count="$OPTARG";;
	f) fil="$OPTARG";;
	x) rmorig=1;;
	\?) usage;;
esac
done

unset xarg targ
if [ $debug ]; then
	# turn on xtrace, xargs verbose, and pass-through -D
	set -o xtrace
	xarg="$xarg --verbose"
	targ="$targ -D"
fi

if [ $rmorig ]; then
	targ="$targ -x"
fi

if [ $depth ]; then
	# turn into a 'find' arg
	depth=" -maxdepth $depth"
fi

if [ $pll ]; then
	# run commands in parallel
	xarg="$xarg -P $pll"
fi

shift `expr $OPTIND - 1`
path="$1"

# inject head command
unset head
[ -n "$count" ] && head="head -n $count |"

if [ "$fil" ]; then
	compress "$fil"
elif [ "$path" ]; then
	# image stream
	find "$path" $depth \( -name '*.jpg' -or -name '*.jpeg' \) -and -not -name '*_adept_compress.jpg' -and -not -name '*_adept_save.jpg' $farg | eval $head xargs $xarg -n 1 "$0" $targ -f
else
	usage 
	exit 1
fi
