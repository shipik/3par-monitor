# 3par-monitor
HP 3PAR Storage Monitor - Health Check

NAME
    check_3par.pl - HP 3PAR Storage Monitor - Health Check

AUTHOR

    Vladimir Shapovalov
    
SYNOPSIS

  check_3par.pl CHECK_COMMAND [3PAR_IP/NAME] [USER] [PASS]

CHECK_COMMAND

    check_pd
         Shows state information about system's physical disks.

    check_node
         Shows state information for nodes or power supply.

    check_vv
         Shows state information about virtual volumes (VVs) in the system.

    showalert
         Displays the status of system alerts.

DESCRIPTION

    Perl script uses Expect to login to 3par service processor via ssh. There is
    no additional software required. Can be used for nagios, op5, etc. monitoring.

EXAMPLES

    #> check_3par.pl check_pd 3par-sp.mycompany.net monitor monitor123

    Output:

     OK! 272 PDs online.
     CRITICAL! PDs in FAILED status   (check 'showpd -failed'):   8 (0:8:0),
     WARNING!  PDs in DEGRADED status (check 'showpd -degraded'): 8 (0:8:0),
     INFO!     PDs in NEW status      (check 'showpd -state'):    3 (0:3:0),
     CRITICAL! PDs in FAILED status   (check 'showpd -failed'):   8 (0:8:0), WARNING! PDs in DEGRADED status (check 'showpd -degraded'): 6 (0:6:0), 7 (0:7:0),
     8 (0:8:0) => ID (CagePos)

    #> check_3par.pl check_node 3par-sp.mycompany.net monitor monitor123

    Output:

     OK!  nodes online.
     CRITICAL! nodes in FAILED status   (check 'shownode -state'): 2 (pci_error, unknown),
     WARNING!  nodes in DEGRADED status (check 'shownode -state'): 1 (cpu_vrm_overheating,tod_bat_fail),
     CRITICAL! nodes in FAILED status   (check 'shownode -state'): 2 (pci_error, unknown), WARNING!  nodes in DEGRADED status (check 'shownode -state'): 1 (cpu_vrm_overheating,tod_bat_fail), 
     2 (pci_error, unknown) => NODE_ID (Detailed_State)

    #> check_3par.pl check_vv 3par-sp.mycompany.net monitor monitor123

    Output:

     OK! 130 VVs online.
     CRITICAL! VVs in FAILED status   (check 'showvv -state'): 7 (fc_vol.1),
     WARNING!  VVs in DEGRADED status (check 'showvv -state'): 1 (.srdata),
     CRITICAL! VVs in FAILED status   (check 'showvv -state'): 7 (fc_vol.1), 8 (fc_vol.2), WARNING!  VVs in DEGRADED status (check 'showvv -state'): 1 (.srdata), 9 (fc_vol.3),
     7 (fc_vol.1) => VV_ID (VV_NAME)

    #> check_3par.pl showalert 3par-sp.mycompany.net monitor monitor123

    Output:

     OK! No new alerts.
     CRITICAL! Alerts with severity Fatal, Critical or Major (check 'showalert -n'),
     WARNING!  Alerts with severity DEGRADED (check 'showalert -n'),

TODO

    showbattery showcpg showcage showport

