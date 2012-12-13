#!/bin/bash
#curl http://weather.noaa.gov/pub/data/observations/metar/decoded/KDMH.TXT #option 1 (baltimore)
#station=kdca (DC)
#apt-get install weather
#weather kdmh|grep Temperature
#weather kdmh|grep Temperature|cut -b 25,26,27,28
#baltimore=$(weather kdmh|grep Temperature|cut -b 25,26,27,28)
#or
#dc=$curl http://weather.noaa.gov/pub/data/observations/metar/decoded/KDCA.TXT|grep Temperature|cut -b 22,23,24,25)
#dc=$(curl -s http://weather.noaa.gov/pub/data/observations/metar/decoded/KDCA.TXT|grep Temperature|cut -c 20-)
#dc=$(curl -s http://weather.noaa.gov/pub/data/observations/metar/decoded/KDCA.TXT|grep Temperature|cut -c 13-|cut -d " " -f 4)
echo dc
