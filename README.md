rpi-thermometer
===============
Given
-----------
Intended for use with Raspberry Pi running Raspbian with 1wire solution. Tested only with this sensor gear:
*Sensor 18S20 w/o moisture resistant coating
*1wire USB adaptor DS9490R-P
*Adaptor cable RJ-45 to RJ-11 (1 meter)

Purpose
----------
Used with a single sensor to store and graph temperature over time. Produces a web page with:
*Graph of last 1 day of reading in hours (celsius only)
*Last Reading Date/time, Degrees C, Degrees F
*In preformatted text: last 100 reading (earliest to latest)

Usage
-----
Use in conjunction with cron (sudo crontab -e). Configure to launch rpi-thermostat.sh every minute (the RRD database expects every 300 seconds).
Includes an install and configuration function: rpi-thermostat.sh config

After running the script with the config argument, it's up to you to set a cron job: sudo crontab -e; end the file thusly:
     * * * * * /usr/local/bin/rpi-thermometer. That will update the graphs, database, logs, and web page every minute.

Setup logrotate. Help soon.

To Do
-----
*Comment for others
*Add citeography
*values argument: function got lost in revision shuffle. It should dump current settings.
*Configure logrotate
*Install sqlite db and log data to sqlite for better versatility and web integration. Needed for progress in webdev
*change license based on student decision and as requested
*change copyright (waiting for admin advisement)

Source
------
Used this, perhaps unwisely: http://neilbaldwin.net/blog/weather/raspberry-pi-data-logger/

Reflection
---------
Coming to http://gonzotech.tumblr.com as soon as I get sed and cut options outta my head.
