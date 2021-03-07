#!/bin/bash


# bash docker-entrypoint.sh produce /tmp/produce/example > example.tar.gz
# we are creating dummy project on the fly, not mounting it from host
# if the host already has the project, it can be tar zipped on host and piped to docker serve
produce() {
	local mkdocsFullPath="$1"
	local mkdocsParentDir=$(dirname $mkdocsFullPath)
	local mkdocsDir=$(basename $mkdocsFullPath)

	mkdir -p $mkdocsParentDir && \
	cd $mkdocsParentDir && \
	mkdocs new $mkdocsDir && \
	cd $mkdocsParentDir/$mkdocsDir && \
	mkdocs build && \
	tar -C $mkdocsParentDir -cf - $mkdocsDir
}

# cat example.tar.gz | WWWDIR=/tmp/serve bash docker-entrypoint.sh serve
serve() {

	local wwwDir=${WWWDIR:-/var/tmp/www}
	mkdir -p $wwwDir && \
	cd $wwwDir && \
	tar -C $wwwDir -xvf -

	if [ ! -d $wwwDir ]
	then
		throw "[$wwwDir] does not exist"
	fi

	mkdocsDir=$(find $wwwDir -maxdepth 2 -type f -name mkdocs.yml 2>/dev/null | sed  -e 's,/mkdocs.yml,,')
	if [ -d $mkdocsDir ]  # full path to mkdocsDir
	then
		cd $mkdocsDir
		exec mkdocs serve --dev-addr=${HOST}:${PORT}  # exec for SIGINT to work
	fi
}


############################################## MAIN

PROGRAMNAME=$0

# create a copy of args
args=("$@")

# capture the action produce/serve
action=${args[0]}

throw() {
	echo $1 >&2
	exit 1
}
HOST=0.0.0.0
PORT=8000

################################ check tar/mkocs binary is present , exit 
if ! command -v tar >/dev/null
then
	 throw "ERROR: Cannot find <tar> binary"
fi

if ! command -v mkdocs >/dev/null
then
	 throw "ERROR: Cannot find <mkdocs> binary"
fi


################################   RUN

if [ "${action}" == "produce" ]
then
	produce "${args[1]}"

elif [ "$action" == "serve" ]
then
	serve "${args[1]}"
else
	throw "Usage $PROGRAMNAME [produce <path/to/mkdocs_dir_on_guest>|serve]"
fi
