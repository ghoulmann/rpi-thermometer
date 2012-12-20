############
#Configuration Options
############
executeable="rpi-thermometer"
webroot="/var/www" #where to put the web files (index.html)
graphdir="/var/www/images" #where to put the graphics (by default, for web)
sensor1="/mnt/1wire/10.98C57C020800/temperature" #sensor1. Read like a file.
thermometer_log_path="/var/log/temperature" #where to put temp log
thermometer_log="temperature.log" #by default, /var/log/temperature/temperature.log (thinking logrotate)
path_to_db="/var/local" #not sure where by FHS guidelines
db="thermometer.rrd" #name of rrd database to create
weather_home="index.html" #weather web home file
executable_dir="/usr/local/bin" #for rpi-thermometer. Not sure by FHS convention.
stamp=$(date)
key=$(date +%s) #epoch in linux
weathers_station="KDCA"
local_outside=$(curl -s http://weather.noaa.gov/pub/data/observations/metar/decoded/$weather_station.TXT|grep Temperature|cut -c 13-|cut -d " " -f 4|cut -c 2-) #substitute $weather_station for KDCA
confpath="/etc"
conffile="thermometer.conf"
reading1=$(cat $sensor1)
#include configuration file
. $confpath/$conffile


#check for root
check_for_root ()
{
	if [[ $EUID -ne 0 ]]; then
    	echo "$0 must be run as root	." 1>&2
    	exit 1
	fi
}


usage ()
{
	echo "rpi-thermometer is called with an argument (required)."
	echo "rpi-thermometer config rrdtool:"
	echo "rpi-thermometer config cacti:"
	echo "rpi-thermometer config graphite"
	echo "rpi-thermometer values: Display configured/configureable variables and values to stdout."
	echo "rpi-thermometer update: Updates values in the database, log, and regenerates web page and generates graphs; requires root"
}

#"install" script to $executeable_dir
executeable()
{
		if [ ! -e $executable_dir/$executeable ]; then
			cp $0 $executable_dir/$executeable
			chown root:sudo $executable_dir/$executeable
			chmod +x $executable_dir/$executeable
		fi
	
}

rrdtool_update ()
{
	rrdtool update $path_to_db/$db N:$reading1:$local_outside
}

rrdtool_graph ()
{
	#second data point isn't graphed yet
	rrdtool graph $graphdir/temp_h.png --start -1d --end now --x-grid MINUTE:10:HOUR:1:HOUR:2:0:%H:00 --vertical-label "Celsius" DEF:sensor=$path_to_db/$db:sensor:AVERAGE LINE1:sensor#0000FF:"Temperature [deg C]"
	#Create other graphs
	rrdtool graph $graphdir/temp_d.png --start -1d --vertical-label "Celsius" DEF:sensore=$path_to_db/$db:sensore:AVERAGE LINE1:sensor#0000FF:"Temperature [deg C]"
	rrdtool graph $graphdir/temp_w.png --start -1w --vertical-label "Celsius" DEF:sensor=$path_to_db/$db:sensor:AVERAGE LINE1:sensor#0000FF:"Temperature [deg C]"
	rrdtool graph $graphdir/temp_m.png --start -1m --vertical-label "Celsius" DEF:sensor=$path_to_db/$db:sensor:AVERAGE LINE1:sensor#0000FF:"Temperature [deg C]"
	rrdtool graph $graphdir/temp_y.png --start -1y --vertical-label "Celsius" DEF:sensor=$path_to_db/$db:sensor:AVERAGE LINE1:sensor#0000FF:"Temperature [deg C]"
	#make graphs web accessible
	chown -R www-data:www-data $graphdir/
}


log ()
{
	if [ $toolset == "rrdtool" ]; then
		rrdtool_update
		rrdtool_graph
	elif [ $toolset == "cacti" ]; then
		rrdtool_update
	elif [ $toolset == "graphite" ]; then
		server="localhost"
		port="2003"
		echo "local.temperature.celsius.sensor1 $reading1 $key" | nc ${server} ${port};
	else
		exit 1
	fi
}

#Function to create rrd log
create_rrd_database ()
{
	rrdtool create $path_to_db/$db --start N --step 300 \
	DS:sensor:GAUGE:600:0:100 \
	DS:outside:GAUGE:600:0:100 \
	RRA:AVERAGE:0.5:1:12 \
	RRA:AVERAGE:0.5:1:288 \
	RRA:AVERAGE:0.5:12:168 \
	RRA:AVERAGE:0.5:12:720 \
	RRA:AVERAGE:0.5:288:365
}

make_conf ()
{
	echo "toolset=$2" > $confpath/$conffile
}

rrdtool_install ()
{
	create_rrd_database
}

cacti_install ()
{

}

graphite_install ()
{

}
#Install and configure
#make conf file in confpath
make_conf
#install the tools
if [ "$1" == "config" ]; then
	if [ "$2" == "rrdtool" ]; then
		check_for_root
		executeable
		rrdtool_install
	elif [ "$2" == "cacti" ]; then
		check_for_root
		executeable
		cacti_install
	elif [ "$2" == "graphite" ]; then
		check_for_root
		executeable
		graphite_install
	else
		usage
	fi
elif [ "$1" == "update" ]; then
	check_for_root
	log
	exit 0
elif [ "$1" == "values" ]; then
	echo "echo values here"     # TO DO
	exit 0
elif [ "$1" == "remove" ]; then
	remove
	exit 0
else
	usage
	exit 0
fi
