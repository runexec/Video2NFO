#!/bin/bash

#-
# Copyright (c) 2012 Ryan Kelker and individual contributors.
# ( https://github.com/runexec/Video2NFO )
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer
# in this position and unchanged.
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
# 3. The name of the author may not be used to endorse or promote products
# derived from this software withough specific prior written permission
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES# LOSS OF USE,
# DATA, OR PROFITS# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#
# *** Required Dependencies ***
#
# Created and tested with =>
#
# Name           : bc
# Version        : 1.06-8
# URL            : http://www.gnu.org/software/bc/
#
# Name           : ffmpeg
# Version        : 20120127-3
# URL            : http://ffmpeg.org/
#
# Name           : imagemagick
# Version        : 6.7.6.0-1
# URL            : http://www.imagemagick.org/
#
# Name           : mplayer
# Version        : 34799-1
# URL            : http://www.mplayerhq.hu/

VIDEO_FILE="${1}"

DURATION=`ffmpeg -i "${VIDEO_FILE}" 2>&1 | 
grep "Duration: " |
awk '{split($0,duration,","); print duration[1]}' |
tr ' ' '\n' | 
grep -v D |
tail -1` # DURATION.end

VIDEO_WIDTH=`ffmpeg -i "${VIDEO_FILE}" 2>&1 | 
grep "Video: " |
awk '{split($0,vsize,","); print vsize[3]}' |
tr ' ' '\n' | 
grep -v '\[' |
grep x |
cut -d 'x' -f1` # VIDEO_WIDTH.end

VIDEO_HEIGHT=`ffmpeg -i "${VIDEO_FILE}" 2>&1 | 
grep "Video: " |
awk '{split($0,vsize,","); print vsize[3]}' |
tr ' ' '\n' | 
grep -v '\[' |
grep x |
cut -d 'x' -f2` # VIDEO_HEIGHT.end

SCALED_WIDTH=`echo "$VIDEO_WIDTH*0.40" | bc | cut -d '.' -f1`
SCALED_HEIGHT=`echo "$VIDEO_HEIGHT*0.40" | bc | cut -d '.' -f1`
SCALED_SIZE="${SCALED_WIDTH}x${SCALED_HEIGHT}"

HOUR=`echo $DURATION | cut -d ':' -f1`
MINUTES=`echo $DURATION | cut -d ':' -f2`
HOUR_IN_MINUTES=$(($HOUR*60))

TOTAL_TIME_IN_MINUTES=`echo "$HOUR_IN_MINUTES+$MINUTES" | bc`
TOTAL_TIME_IN_SECONDS=`echo "$TOTAL_TIME_IN_MINUTES*60" | bc`

# Mplayer creates the images because ffmpeg x264 to image sucks

function createImage {
	offset=$1	

	mplayer -vf scale=$SCALED_WIDTH:$SCALED_HEIGHT -frames 1 -ss $offset -nosound -identify -vo png:z=9:prefix=v2nfo. "${VIDEO_FILE}"
	mv "v2nfo.00000001.png" "v2nfo.${offset}.png"
	echo $SCALED_SIZE $offset $VIDEO_FILE	
}

function timeStamp {
	seconds=$1
	s=$seconds

	h=`echo "$s/3600" | bc`
	s=`echo "$s-($h*3600)" | bc`
	m=`echo "$s/60" | bc`
	s=`echo "$s-($m*60)" | bc`
	printf "%d:%02d:%02d" $h $m $s
}

# Duration Perentages

percent=".05"
perc_end=".95"
while true;
do
	if [ $percent == $perc_end ]
	then
		break
	fi
	percent=`echo "$percent+.05" | bc`
	offset=`echo "$TOTAL_TIME_IN_SECONDS*$percent" | bc`
	createImage $offset
done


# explaining the ls cmd:
# list 1 files per line, replace with '.' with space,
# sort numeric of second column, replace space with '.'
# now the video sequence of images are in order from least to greatest
for image in `ls -1 v2nfo*png | tr '\.' ' ' | sort -k 2 -n | tr ' ' '\.'`
do
	# video2nfo watermark
	convert $image -gravity South -pointsize 12 \
		-splice 0x16 -annotate +0+2 'video2nfo.sh - Video 2 NFO' nfotmp.png
	mv nfotmp.png $image

	# screenshot frame
	convert $image -gravity SouthEast -frame 1 nfotmp.png
	mv nfotmp.png $image
	
	# duration stamping
	duration=$(timeStamp `echo $image | cut -d '.' -f2`)
	convert -background '#00000080' -fill white -gravity East -size ${SCALED_WIDTH}x15 \
		caption:"$duration" \
		$image +swap -gravity South -composite nfotmp.png
	mv nfotmp.png $image
done

# ImageMagick v6 to combine images
montage v2nfo.*.png -tile 2x -geometry +1+1 VIDEO_2_NFO.png

# Remove the tmp files
rm v2nfo*.png

