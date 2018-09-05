#!/bin/bash

# GPIO mapping for EN_x signals
pins=(13 26 12 23 27 22)
duts="1 2 3 4 5 6"

error() {
	if [ ! -z "$1" ]; then
		echo $1
	fi
	echo "Format: boards.sh < enable | disable > [ 1 | 2 | 3 | 4 | 5 | 6 ]"
	echo " if no board numbers provided - command applied to all of them"
}

case $1 in
	enable)
		value="1"
		shift
	;;
	disable)
		value="0"
		shift
	;;
	*)
		error "Unknown command $1"
		exit 1
	;;
esac

cmd="$@"

# If no more arguments - apply to all boards
if [ -z $cmd ]; then
	cmd=$duts
fi

for i in $cmd
do
case $i in
	1|2|3|4|5|6)
		pin=${pins[$i-1]}
		echo "out" > /sys/class/gpio/gpio$pin/direction
		echo $value > /sys/class/gpio/gpio$pin/value
	;;
	*)
		error "Unknown board $i"
		exit 1
	;;
esac
done
