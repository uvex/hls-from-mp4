#!/bin/sh
export $(sed 's/&/ /g'<<<$QUERY_STRING)
BASEFILE=$(sed 's/.mp4//g' <<<$file)
MEDIADIR=/data/media; TSDIR=$MEDIADIR/mpts/$BASEFILE
export LD_LIBRARY_PATH=/usr/local/ffmpeg/lib:/usr/lib
FF=/usr/local/ffmpeg/bin/ffmpeg; FP=/usr/local/ffmpeg/bin/ffprobe
INP="$MEDIADIR/$file"; [ ! -d $TSDIR ] && mkdir -p $TSDIR
[ ! -f $MEDIADIR/$file ] && echo 'Status: 404 Not Found'
###Calculate number of fragments from file's time durations
SEGTIME=5
TT=$(($(date -u +%s -d "1970/01/01 $($FP $INP 2>&1|grep Duration:|sed 's/,//g'|awk '{print$2}')")/10))
echo "Content-Type: application/x-mpegURL"
echo ""
if [ ! -f $TSDIR/main.pl ];then
  $FF -i "$INP" -loglevel quiet -flags +global_header+loop+mv4 -bsf h264_mp4toannexb -threads 0 -c copy -q:v 1 -q:a 1 -map 0 -f segment \
  -segment_list $TSDIR/main.pl -segment_list_type flat -segment_time $SEGTIME -segment_format mpegts $TSDIR/s-%1d.ts </dev/null >/dev/null 2>&1 && touch $TSDIR/ts.ok &
  echo -e "#EXTM3U\n#EXT-X-TARGETDURATION:$SEGTIME\n#EXT-X-MEDIA-SEQUENCE: 0"
  for ((i=0;i<=$TT;i++));do
    echo -e "#EXTINF:$SEGTIME, \nhttp://$HTTP_HOST/mpts/$BASEFILE/s-$i.mta"
  done
  echo "#EXT-X-ENDLIST"
else
  echo -e "#EXTM3U\n#EXT-X-TARGETDURATION:$SEGTIME\n#EXT-X-MEDIA-SEQUENCE: 0"
  if [ -f $TSDIR/ts.ok ];then
    awk -F'/' '{print$NF}' $TSDIR/main.pl|while read line;do
     echo -e "#EXTINF:$SEGTIME, \nhttp://$HTTP_HOST/mpts/$BASEFILE/$line"
    done
  else
    for ((i=0;i<=$TT;i++));do
      echo -e "#EXTINF:$SEGTIME, \nhttp://$HTTP_HOST/mpts/$BASEFILE/s-$i.mta"
    done
  fi
  echo "#EXT-X-ENDLIST"
fi
