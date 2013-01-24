mylog.pl
========

#### Just another log tracking tool ####

This script is mainly for personal use, maybe you should look for another
log manager =)


### Installation ###

Make sure you have a perl environment.  
The _utf8_ and _Encode_ modules are required.  
Just alias the script to whatever command you want.  
On the first run, the script will create the following directory  
$HOME/opt/mylog  
or if the _MYLOG\_DIR_ is set, it will use the specified directory.  


### Usage ###

Synopsis:  
mylog.pl [-h|-help|--help] <command> [arguments]  


To write to log  
mylog.pl write \<some string\> [-tag TAGNAME] [-pri PRIORITY]

Try the following:  
>% perl mylog.pl write My first log! -tag test -pri 1
>% perl mylog.pl write Another log! -tag test -pri 2


To read a log  
mylog.pl read \<some string\> [-tag TAGNAME] [-pri PRIORITY] [-key KEYWORD]

Try the following:  
>% perl mylog.pl read \# Show all logs for today
>
>% perl mylog.pl read -tag test \# Show logs with the _test_ tag
>
>% perl mylog.pl read -key first \# Show logs with the keyword _first_
>
>% perl mylog.pl read -pri 2 \# Show logs with priority >= 2
