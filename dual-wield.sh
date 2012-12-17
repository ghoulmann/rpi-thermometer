#!/bin/bash

#Copyright 2012 by Rik Goldman, Chelsea School Students (T.A., L. P. D., J. A. B.)
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


############
#Configuration Options
############
executeable="rpi-thermometer"
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
weathers_station="KDCA"
local_outside=$(curl -s http://weather.noaa.gov/pub/data/observations/metar/decoded/KDCA.TXT|grep Temperature|cut -c 13-|cut -d " " -f 4|cut -c 2-) #substitute $weather_station for KDCA
dummy="16.75" #dummy temperature for troubleshooting flow on a machine w/o sensors
#To install prerequisites and create the database and other stuff required before first use, use with config argument: rpi-thermometer.sh config

###########
#Functions#
###########

usage()
{
	echo "rpi-thermometer is called with a single option (required)."
	echo "rpi-thermometer remove: removes all files, including log files, created during config."
	echo "rpi-thermometer config: Installs by moving the shell script, creating the database, creating the log file, etc."
	echo "rpi-thermometer values: Display configured/configureable variables and values to stdout."
	echo "rpi-thermometer update: Updates values in the database, log, and regenerates web page and generates graphs; requires root"
	echo "rpi-thermometer graph: Generates graphs based on existing data. Does not update."
}

#check for root
check_for_root()
{
	if [[ $EUID -ne 0 ]]; then
    	echo "$0 must be run as root	." 1>&2
    	exit 1
	fi
}

remove()
{
	check_for_root
	rm $path_to_db/$db
	echo "database deleted"
	rm -r $graphdir
	echo $graphdir deleted
	rm $webroot/$weather_home
	echo $webroot/$weather_home deleted
	rm $thermometer_log_path/$thermometer_log
}
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
	DS:temp:GAUGE:600:0:100 \
	RRA:AVERAGE:0.5:1:12 \
	RRA:AVERAGE:0.5:1:288 \
	RRA:AVERAGE:0.5:12:168 \
	RRA:AVERAGE:0.5:12:720 \
	RRA:AVERAGE:0.5:288:365 \
	DS:outside:GAUGE:600:0:100 \
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
	check_for_root
	if [ $dummy == 0 ]; then
		celsius=$(cat $sensor) #test on machine with sensor
		echo $celsius #troubleshooting
		celsius=`echo $celsius | cut -c -4`
	else
		celsius=$dummy
	fi
	fahrenheit=$(echo "scale=2;((9/5) * $celsius) + 32" |bc)
	echo $fahrenheit #troubleshooting
	echo "Starting Log Process" #troubleshooting
	echo "Preparing Date" #troubleshooting
	line=$(echo "$stamp, $celsius (Thermometer1 C), $fahrenheit (Thermometer1 F), $local_outside ($weather_station C")
	echo "This is the logged line: $line"
	#write sensor information to log file
	echo $line >> $thermometer_log_path/$thermometer_log

	#write sensor data to rrdtool database
	echo "writing sensor data to database"
	rrdtool update $path_to_db/$db N:$celsius:$local_outside

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
	rrdtool graph $graphdir/temp_h.png \
	--start -1d --end now \
	--x-grid MINUTE:10:HOUR:1:HOUR:2:0:%H:00 \
	--vertical-label "Celsius" \
	DEF:temp=$path_to_db/$db:temp:AVERAGE LINE1:temp#0000FF:"Sensor [deg C]" \
	DEF:outside=$path_to_db/$db:outside:AVERAGE LINE2:outside#FF0000:"Outside [deg C]"
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
		cp $0 $executable_dir/rpi-thermometer
		chown root:sudo $executable_dir/$executeable
		check
		echo "copied $0 to $executable_dir/$executeable."
		check
		chmod +x $executable_dir/$executeable
		check
	fi
		
	#Add test for -d here
	[ -d $webroot ] || mkdir -p $webroot
	check
	[ -d $graphdir ] || mkdir -p $graphdir
	check
}

#check usage
#if [ $# -ne "2" ]; then
#	usage#
#	exit 1
#fi

#CONFIGURE
if [ "$1" == "config" ]; then
	configure
	check
	#echo "Installation and configuration complete." #Consider pointing to changes made by the config function. Consider instructions for crontab.
	exit 0
elif [ "$1" == "update" ]; then
	check_for_root
	log_temperature
	graph_temperature
	exit 0
elif [ "$1" == "graph" ]; then
	check_for_root
	graph_temperature
	exit 0
elif [ "$1" == "values" ]; then
	echo "values"
	exit 0
elif [ "$1" == "remove" ]; then
	remove
else
	usage
fi
