# 3par-monitor
HP 3PAR Storage Monitor

SYNOPSIS

  check_3par.pl CHECK_COMMAND [3PAR_IP/NAME] [USER] [PASS]

CHECK_COMMAND

    check_pd
         Displays configuration information about system's physical disks.

    check_node
         Displays detailed state information for node or power supply.

    check_vv
         Shows information about virtual volumes (VVs) in the system.

DESCRIPTION

    Script uses Expect to login to 3par service processor via ssh. There is
    no additional software required.

      09.09.16 V0.1 (vs). Initial version
      13.09.16 V0.9 (vs). Final draft
      14.09.16 V1.0 (vs). Added commands: check_pd,check_node,check_vv
      06.10.16 V1.0 (vs). Fixed return codes missmatch. Added nodes count.

TODO

    showbattery showcpg showcage showport

