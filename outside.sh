#!/bin/bash
#curl http://weather.noaa.gov/pub/data/observations/metar/decoded/KDMH.TXT #option 1 (baltimore)
#apt-get install weather
#weather kdmh|grep Temperature
#weather kdmh|grep Temperature|cut -b 25,26,27,28
outside=$(weather kdmh|grep Temperature|cut -b 25,26,27,28)
