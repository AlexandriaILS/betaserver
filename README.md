# betaserver
The script(s) to build / rebuild the staging environment.

The beta server is a Raspberry Pi 2 at the moment, so the expectation is that this script is run on a fresh install after:

* password has been updated
* filesystem has been expanded
* apt update && apt upgrade has been run

This should take care of everything else.

We should end with:

* functional Bubbles install
* AlexandriaILS running on :8000
* Zenodotus running on :8001

Neither of these services will reach the internet directly; there should be an nginx instance that handles proxying traffic. For the particular network that this script is being built for, nginx resides on a different machine and is therefore not considered in this script.