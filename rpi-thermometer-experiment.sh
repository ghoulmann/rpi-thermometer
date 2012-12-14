#!/bin/bash

#Copyright 2012 by Rik Goldman
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

if [[ $EUID -ne 0 ]]; then
   echo "$0 must be run as root." 1>&2
   exit 1
fi

############
#Configuration Options
############
webroot="/usr/share/nginx/www" #where to put the web files (index.html)
graphdir="/usr/share/nginx/www/images" #where to put the graphics (by default, for web)
sensor="/mnt/1wire/10.98C57C020800/temperature" #sensor. Read like a file.
thermometer_log_path="/var/log/temperature" #where to put temp log
thermometer_log="temperature.log" #by default, /var/log/temperature/temperature.log (thinking logrotate)
path_to_db="/var/local" #not sure where by FHS guidelines
db="temperature.rrd" #name of rrd database to create
weather_home="index.html" #weather web home file
executable_dir="/usr/local/bin" #for rpi-thermometer.sh. Not sure by FHS convention.
origin=$(pwd) #unnecessary now
stamp=$(date)
key=$(date +%s) #epoch in linux; perhaps key field if we use sqlite
weather_station="KDCA"
local_outside=$(curl -s http://weather.noaa.gov/pub/data/observations/metar/decoded/$weather_station.TXT|grep Temperature|cut -c 13-|cut -d " " -f 4|cut -c 2- >> outside.txt) #substitute $weather_station for KDCA



#To log (in conjunction with, for example,cron) execute this without arguments.
#To install prerequisites and create the database and other stuff required before first use, use with config argument: rpi-thermometer.sh config

#Usage function. Not sure best way to do this.
#usage()
#{
#
#}

###########
#Functions#
###########

#I think this is unused now
function check #function syntax 1
{
	if [[ $? -ne 0 ]];
		then
		echo "$0 encountered an error. Now exiting."
		exit 1
	fi
}

#Update and Install from repos
install () #function syntax 2
{
	apt-get update
	DEBIAN_FRONTEND=noninteractive apt-get -y \
        -o DPkg::Options::=--force-confdef \
        -o DPkg::Options::=--force-confold \
        install $@
}

#Function to create rrd log
create_database ()
{
	rrdtool create $path_to_db/$db --start N --step 300 \
	DS:probe:GAUGE:600:0:100 \
	DS:$weather_station:600.0.100 \
	RRA:AVERAGE:0.5:1:12 \
	RRA:AVERAGE:0.5:1:288 \
	RRA:AVERAGE:0.5:12:168 \
	RRA:AVERAGE:0.5:12:720 \
	RRA:AVERAGE:0.5:288:365
	check
}

#all the logging stuff
log_temperature ()
{

	probe=$(cat $sensor)
	echo $probe #troubleshooting
	probe=`echo $probe | cut -c -4`
	fahrenheit=$(echo "scale=2;((9/5) * $probe) + 32" |bc)
	echo $fahrenheit #troubleshooting
	echo "Starting Log Process" #troubleshooting
	echo "Preparing Date" #troubleshooting
	line=$(echo "$stamp, $probe, $local_outside, $fahrenheit")
		#write sensor information to log file
	echo $line >> $thermometer_log_path/$thermometer_log

	#write sensor data to rrdtool database
	echo "writing sensor data to database"
	rrdtool update $path_to_db/$db -d probe N:$probe
	rrdtool update $path_to_db/$db -d $weather_station N:$local_outside

	####################################
	#write weather station web site#####
	####################################
	echo "Creating web page with heredoc" #troubleshooting
	cat <<EOD >$webroot/$weather_home
	<html>
		<head>
			<title>Weather Station</title>
			<meta http-equiv="refresh" content="15">
		</head>
		<body bgcolor="white" text="black">
			<center><h1>Weather Station</h1></center>
			<center><img src="images/temp_h.png"></center>
			<p><center><bold>Last Update: $now |Temperature (Fahrenheit): $fahrenheit | Temperature (Celsius): $celsius</bold></center></p>
EOD
	echo "<pre>" >> $webroot/$weather_home
	tail -100 $thermometer_log_path/$thermometer_log >> $webroot/$weather_home
	echo "</pre></body></html>" >> $webroot/$weather_home
	chown www-data:www-data $webroot/$weather_home
}

graph_temperature ()
{
	echo "Creating graphs"
	#Create temp_h.png - customized to see if it helps getting data graphed. Not sure it made a difference
	rrdtool graph $graphdir/temp_h.png --start -1d --end now --x-grid MINUTE:10:HOUR:1:HOUR:2:0:%H:00 --vertical-label "Celsius" DEF:probe=$path_to_db/$db:probe:AVERAGE LINE1:probe#0000FF:"Thermometer [deg C]" DEF:$weather_station=$path_to_db/$db:$weather_station:AVERAGE LINE2:$weather_station#45c75b:"Thermometer [deg C]"
	#Create other graphs
	#rrdtool graph $graphdir/temp_d.png --start -1d --vertical-label "Celsius" DEF:temp=$path_to_db/$db:temp:AVERAGE LINE1:temp#0000FF:"Temperature [deg C]"
	#rrdtool graph $graphdir/temp_w.png --start -1w --vertical-label "Celsius" DEF:temp=$path_to_db/$db:temp:AVERAGE LINE1:temp#0000FF:"Temperature [deg C]"
	#rrdtool graph $graphdir/temp_m.png --start -1m --vertical-label "Celsius" DEF:temp=$path_to_db/$db:temp:AVERAGE LINE1:temp#0000FF:"Temperature [deg C]"
	#rrdtool graph $graphdir/temp_y.png --start -1y --vertical-label "Celsius" DEF:temp=$path_to_db/$db:temp:AVERAGE LINE1:temp#0000FF:"Temperature [deg C]"
	#make graphs web accessible
	chown -R www-data:www-data $graphdir/
	
}

#configuration function
function configure()
{
	#Install dependencies
	install nginx rrdtool owfs sqlite bc
	check

	#Create RRD with RRD Tool
	if [ ! -e $path_to_db/$db ]; then
		create_database
		check
		echo "$path_to_db/$db created."
	fi

	#Create log file
	[ -e $thermometer_log_path ] || mkdir -p $thermometer_log_path
	check
	touch $thermometer_log_path/$thermometer_log
	check
	if [ ! -e $thermometer_log_path/$thermometer_log ]; then
		echo "There was an error creating the log file"
	fi
	
	#Move executeable script
	if [ ! -e $executable_dir/$0 ]; then
		cp $origin/$0 $executable_dir/$0
		check
		echo "Moved $0 to $executable_dir."
		chmod +x $origin/$0
		check
	fi
		
	#Add test for -d here
	mkdir -p $webroot
	check
	#test -d for directory
	mkdir -p $graphdir
	check
}

#CONFIGURE
if [ "$1" == "config" ]; then
	configure
	check
	echo "Installation and configuration complete." #Consider pointing to changes made by the config function. Consider instructions for crontab.
	exit 0
elif [ "$1" == "update" ]; then
	#Log Temperature
	echo "Logging Temperature" #troubleshooting
	log_temperature #call function
	#Graph Temperature
	echo "Graphing Temperature" #troubleshooting
	graph_temperature #call function
fi