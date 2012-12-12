#!/bin/bash -ex
origin=$(pwd)
############
#Configuration Options
############
webroot="/usr/share/nginx/www" #comment
graphdir="/usr/share/nginx/www/images" #comment
sensor="/mnt/1wire/10.98C57C020800/temperature" #comment
thermometer_log_path="/var/log/temperature" #comment
thermometer_log="temperature.log" #comment
path_to_db="/var/local" #comment
db="temperature.rrd" #comment
weather_home="index.html" #comment
#config_dir="/etc" #for rpi-thermometer.conf
executable_dir="/usr/local/bin" #for rpi-thermometer
###########
#Functions#
###########

#Exit on Error
function check()
{
	if [[ $? -ne 0 ]];
		then
		echo "Encountered an error. Now exiting."
		exit 1
	fi
}

#Check for root
function privs()
{
	if [[ $EUID -ne 0 ]]; then
	   echo "This script must be run as root" 1>&2
	   exit 1
	fi
}

#Update and Install
install ()
{
	apt-get update
	DEBIAN_FRONTEND=noninteractive apt-get -y \
        -o DPkg::Options::=--force-confdef \
        -o DPkg::Options::=--force-confold \
        install $@
}

create_database()
{
	rrdtool create $path_to_db/$db --start N --step 300 \
	DS:temp:GAUGE:600:0:100 \
	RRA:AVERAGE:0.5:1:12 \
	RRA:AVERAGE:0.5:1:288 \
	RRA:AVERAGE:0.5:12:168 \
	RRA:AVERAGE:0.5:12:720 \
	RRA:AVERAGE:0.5:288:365	
}

function get_temperature()
{
	celsius=`cat /mnt/1wire/10.98C57C020800/temperature`
	return sensor
}

get_fahrenheit()
{
	fahrenheit=$(echo "scale=2;((9/5) * $celsius) + 32" |bc)
	return $fahrenheit
}
log_temperature()
{
	#Prepare Date
	stamp=$(date)
	line=$(echo '$stamp, $celsius, $fahrenheit')

	#write sensor information to log file
	echo $line >> $thermometer_log_path/$thermometer_log

	#write sensor data to rrdtool database
	rrdtool update $path_to_db/$db N:$temp

	####################################
	#write weather station web site#####
	####################################
	#Create web page with heredoc
	cat <<EOD >$webroot/$weather_home
	<html>
		<head>
			<title>Weather Station</title>
			<meta http-equiv="refresh" content="15">
		</head>
		<body bgcolor="white" text="black">
			<center><h1>108B Weather Station</h1></center>
			<center><img src="images/temp_h.png"></center>
			<center><bold>Last Update: $now |Temperature (Fahrenheit): $fahrenheit | Temperature (Celsius): $celsius</bold></center>
EOD
	echo "<pre>" >> $webroot/$weather_home
	tail -100 $thermometer_log_path/$thermometer_log >> $webroot/$weather_home
	echo "</pre></body></html>" >> /usr/share/nginx/www/index.html
	chown www-data:www-data /usr/share/nginx/www/index.html
}

graph_temperature()
{
	#Create temp_h.png
	rrdtool graph $graphdir/temp_h.png --start -1d --end now --x-grid MINUTE:10:HOUR:1:HOUR:2:0:%H:00 --vertical-label "Celsius" DEF:temp=$db:temp:AVERAGE LINE1:temp#0000FF:"Temperature [deg C]"
	#Create other graphs
	rrdtool graph $graphdir/temp_d.png --start -1d --vertical-label "Celsius" DEF:temp=$db:temp:AVERAGE LINE1:temp#0000FF:"Temperature [deg C]"
	rrdtool graph $graphdir/temp_w.png --start -1w --vertical-label "Celsius" DEF:temp=$db:temp:AVERAGE LINE1:temp#0000FF:"Temperature [deg C]"
	rrdtool graph $graphdir/temp_m.png --start -1m --vertical-label "Celsius" DEF:temp=$db:temp:AVERAGE LINE1:temp#0000FF:"Temperature [deg C]"
	rrdtool graph $graphdir/temp_y.png --start -1y --vertical-label "Celsius" DEF:temp=$db:temp:AVERAGE LINE1:temp#0000FF:"Temperature [deg C]"
	chown -R www-data:www-data $graphdir/
	#0000FF means blue trace color in the graphs.
}

#check for root
#privs()
#check()
############
#Configuration Options
############

#INSTALLATION AND SETUP


###########################
#repo update and install###
###########################
#uses install function to apt-get update and install

if [ "$1" == "config" ]; then
	privs
	function configure()
	{
		#Install dependencies
		install nginx rrdtool owfs sqlite bc
		check
	
		#Create RRD with RRD Tool
		if [ ! -e $path_to_db/$db]; then
			create_database $path_to_db $db
			echo "$path_to_db/$db created."
		fi

		#Create log file
		touch $thermometer_log_path/$thermometer_log
		if [ ! -e $thermometer_log_path/$thermometer_log ]; then
			echo "There was an error creating the log file"
		fi
	
		#Move executeable script
		if [ ! -e $executable_dir/$0 ]; then
			mv $origin/$0 $executable_dir/$0
			check
			echo "Moved $0 to $executable_dir."
			chmod +x $origin/$0
			check
		fi
		
		#if test here
		mkdir -p $webroot
		check
		#iftest here
		mkdir -p $graphdir
		check
	}
	configure
	echo "Installation and configuration complete."
fi
