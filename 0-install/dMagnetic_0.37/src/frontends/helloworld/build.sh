#!/bin/sh
(
	cd ../../../
	make libdmagnetic.a
)

gcc -c -o helloworld.o helloworld.c -I../../libdmagnetic
gcc -o helloworld helloworld.o -L../../../ -ldmagnetic
