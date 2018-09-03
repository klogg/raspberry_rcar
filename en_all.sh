#!/bin/sh

# EN_1 - pin 33 - GPIO13
echo "out" > /sys/class/gpio/gpio13/direction
echo "1" > /sys/class/gpio/gpio13/value

# EN_2 - pin 37 - GPIO26
echo "out" > /sys/class/gpio/gpio26/direction
echo "1" > /sys/class/gpio/gpio26/value

# EN_3 - pin 32 - GPIO12
echo "out" > /sys/class/gpio/gpio12/direction
echo "1" > /sys/class/gpio/gpio12/value

# EN_4 - pin 16 - GPIO23
echo "out" > /sys/class/gpio/gpio23/direction
echo "1" > /sys/class/gpio/gpio23/value

# EN_5 - pin 13 - GPIO27
echo "out" > /sys/class/gpio/gpio27/direction
echo "1" > /sys/class/gpio/gpio27/value

# EN_6 - pin 15 - GPIO22
echo "out" > /sys/class/gpio/gpio22/direction
echo "1" > /sys/class/gpio/gpio22/value

