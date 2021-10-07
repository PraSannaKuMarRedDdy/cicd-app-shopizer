#!/bin/bash
cd /usr/local/tomcat9/bin
./startup.sh
nohup java -jar /usr/local/tomcat9/webapps/sm-shop-2.17.0.war &