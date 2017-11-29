#!/usr/bin/perl

=head1 NAME

B<check_3par.pl> - 3PAR monitoring check script

=head1 AUTHOR

Vladimir Shapovalov <shapovalov@gmail.com>

=head1 SYNOPSIS

B<check_3par.pl> CHECK_COMMAND [3PAR_IP/NAME] [USER] [PASS]

=head1 CHECK_COMMAND

=over 5

=item B<check_pd>

Displays configuration information about system's physical disks.

=item B<check_node>

Displays detailed state information for node or power supply.

=item B<check_vv>

Shows information about virtual volumes (VVs) in the system.

=item B<showalert>

Displays the status of system alerts.

=back

=head1 DESCRIPTION

Script uses Expect to login to 3par service processor via ssh. There is no additional software required.

  09.09.16 V0.1 (vs). Initial version
  13.09.16 V0.9 (vs). Final draft
  14.09.16 V1.0 (vs). Added commands: check_pd,check_node,check_vv
  06.10.16 V1.0 (vs). Fixed return codes missmatch. Added nodes count.
  14.09.16 V1.0 (vs). Added commands: showalert

=head1 TODO

showbattery
showcpg
showcage
showport

=head1 LICENSE

MIT License - feel free!

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=head1 EXAMPLES

=cut

use strict;
use Data::Dumper;
use Expect;

my $VERSION = 'V1.1';
my $timeout = 60;
my $srv = "";
my $user = "3parmon";
my $pass = "passwd";
my $countNodes = 4; # seems to be a bug in 3par OS. If one node missing, shownode and showsys do not show missing node. So as it wouldn't newer have been available. Only online nodes shown in state "OK", no missing node in bad status. The workaround is to define how many nodes the system has.
my @params;
my %checkCommands = (
                      'check_pd'    => 'showpd -showcols Id,CagePos,State', # Displays configuration information about a system's physical disks.
                      'check_node'  => 'shownode -state', # Displays the detailed state information for node or power supply.
                      'check_vv'    => 'showvv -showcols Id,Name,State', # Shows information about virtual volumes (VVs) in the system.
                      'showalert'   => 'showalert -n', # Displays the status of system alerts.
                    );
my %returnCodes   = (
                      'OK'        => '0',
                      'WARNING'   => '1',
                      'CRITICAL'  => '2',
                      'UNKNOWN'   => '3',
                    );
my $returnState    = 'UNKNOWN';
my $checkCommand = $ARGV[0];
if(!$checkCommand || $checkCommand eq ""){
  print "Incorrect usage: check_3par.pl CHECK_COMMAND [3PAR_IP/NAME] [USER] [PASS]\n";
  exit $returnCodes{'CRITICAL'};
}
if(!$checkCommands{$checkCommand}){
  print "Incorrect usage (invalid CHECK_COMMAND): check_3par.pl CHECK_COMMAND [3PAR_IP/NAME] [USER] [PASS]\n";
  print "commands:\n".join( "\n", keys(%checkCommands))."\n";
  exit $returnCodes{'CRITICAL'};
}

$srv  = $ARGV[1] if ($ARGV[1]);
$user = $ARGV[2] if ($ARGV[2]);
$pass = $ARGV[3] if ($ARGV[3]);

if(!$srv){
  print "Incorrect usage (invalid 3PAR_IP/NAME): check_3par.pl CHECK_COMMAND [3PAR_IP/NAME] [USER] [PASS]\n";
  exit $returnCodes{'CRITICAL'};
}

my $sshStr = "/usr/bin/ssh $user\@$srv";
my $command = $sshStr." ".$checkCommands{$checkCommand};

my $exp = Expect->spawn($command, @params) or die "Cannot spawn $command: $!\n";
$exp->log_stdout(undef);

my $output;
my @out;

@out = $exp->expect($timeout,
           [ qr/assword:/ => sub { my $exp = shift;
                                 $exp->send("$pass\n");
                                 $output = $exp->exp_after;
                                 exp_continue; } ],
           [ qr/sure you want to continue connecting \(yes\/no\)\?/i => sub { my $exp = shift;
                                 $exp->send("yes\n");
                                 $output = $exp->exp_after;
                                 exp_continue; } ],
          ) or die("could not spawn... $!");


# replace CRLF with LF
$out[3] =~ s/[\x0A\x0D][\x0A\x0D]/\n/gms;

if($exp->exitstatus() > 0){
  print "ERROR: cannot execute command:\n$command\n$out[3]$out[1]\n";
  exit $returnCodes{'CRITICAL'};
}

if($checkCommand eq "check_pd"){

=pod

#> B<check_3par.pl> check_pd 3par-sp.mycompany.net monitor monitor123

Output:

 OK! 272 PDs online.
 CRITICAL! PDs in FAILED status   (check 'showpd -failed'):   8 (0:8:0),
 WARNING!  PDs in DEGRADED status (check 'showpd -degraded'): 8 (0:8:0),
 INFO!     PDs in NEW status      (check 'showpd -state'):    3 (0:3:0),
 CRITICAL! PDs in FAILED status   (check 'showpd -failed'):   8 (0:8:0), WARNING! PDs in DEGRADED status (check 'showpd -degraded'): 6 (0:6:0), 7 (0:7:0),
 8 (0:8:0) => ID (CagePos)

=cut

<<'COMMENT';
#> showpd -showcols Id,CagePos,State

  Id           Identifier of the physical disk.
  CagePos      Position of the PD. <cage>:<mag>:<disk>
  State        State of the PD, can be one of the following:
                 normal   PD is normal
                 degraded PD is not operating normally. Use "showpd -state" to
                          find out the detail information
                 new      PD is new, needs to be admitted before it can be
                          used (see help admitpd)
                 failed   PD has failed
COMMENT

  my %pds;
  my $pdsTotal    = 0;
  my $pdsFailed   = 0;
  my $pdsDegraded = 0;
  my $pdsNew      = 0;
  my $strOut          = "OK! ";
  my $strOutFailed    = "CRITICAL! PDs in FAILED status   (check 'showpd -failed'): "; 
  my $strOutDegraded  = "WARNING!  PDs in DEGRADED status (check 'showpd -degraded'): ";
  my $strOutNew       = "INFO!     PDs in NEW status      (check 'showpd -state'): ";

  $out[3] =~ s/^\s*----+.*//gms;

  my @res = split("\n", $out[3]);
  foreach my $i (2..$#res){
    next if($res[$i] =~ /^\s*$/);

    $res[$i] =~ /^\s*(\d+)\s+(.*?)\s+(\w+)/;

    if(lc($3) eq "failed"){
      $strOutFailed .= "$1 ($2), ";
      $pdsFailed++;
    }
    elsif(lc($3) eq "degraded"){
      $strOutDegraded .= "$1 ($2), ";
      $pdsDegraded++;
    }
    elsif(lc($3) eq "new"){
      $strOutNew .= "$1 ($2), ";
      $pdsNew++;
    }
   else{}
    $pdsTotal++;
  }

  $strOut .= $pdsTotal." PDs online.";
  $returnState = 'OK';

  if($pdsFailed   > 0){
    $strOut     =  $strOutFailed;
    $returnState = 'CRITICAL';
  }
  if($pdsDegraded > 0){
    $strOut     =  $strOutDegraded;
    $returnState = 'WARNING';
  }
  if($pdsNew > 0){
    $strOut     =  $strOutNew;
    $returnState = 'OK';
  }
  if($pdsFailed   > 0 && $pdsDegraded > 0){
    $strOut     =  $strOutFailed.$strOutDegraded;
    $returnState = 'CRITICAL';
  }

  print "$strOut\n";
  $exp->soft_close();
  exit $returnCodes{$returnState};
}
elsif($checkCommand eq "check_node"){

=pod

#> B<check_3par.pl> check_node 3par-sp.mycompany.net monitor monitor123

Output:

 OK!  nodes online.
 CRITICAL! nodes in FAILED status   (check 'shownode -state'): 2 (pci_error, unknown),
 WARNING!  nodes in DEGRADED status (check 'shownode -state'): 1 (cpu_vrm_overheating,tod_bat_fail),
 CRITICAL! nodes in FAILED status   (check 'shownode -state'): 2 (pci_error, unknown), WARNING!  nodes in DEGRADED status (check 'shownode -state'): 1 (cpu_vrm_overheating,tod_bat_fail), 
 2 (pci_error, unknown) => NODE_ID (Detailed_State)

=cut

<<'COMMENT';
#> shownode -state

 Node           Node ID
 State          Node state
                 OK              Node and its components are operating normally
                 Degraded        Node is degraded when the power supply is 
                                 missing, failed, or degraded (fan failed, 
                                 battery max life low, failed, expired, or not
                                 present
                 Failed          Node is not initialized, offline, kernel 
                                 revision mismatched, IDE partition bad, 
                                 rebooting, or shutdown
 Detailed_State
               Detailed state of node is one or more of
                 tod_bat_fail       
                                 Time-Of-Day Battery Failure  
                 invalid_bat_config 
                                 Invalid Battery Configuration
                 link_error         
                                 Link Error
                 uncorrectable_mem_error     
                                 Uncorrectable Memory Error
                 multi_uncorrectable_mem_error 
                                 Multiple Uncorrectable Memory Error
                 correctable_mem_error       
                                 Correctable Memory Error
                 internal_system_error 
                                 Internal System Error
                 hardware_watchdog_error 
                                 Hardware Watchdog Error
                 pci_error  
                                 PCI Error
                 driver_software_error 
                                 Driver Software Error
                 cpu_overheating 
                                 CPU Overheating
                 cpu_vrm_overheating 
                                 CPU VRM Overheating
                 control_cache_dimm_overheating 
                                 Control Cache DIMM Overheating
                 node_offline_due_to_failure 
                                 Node Offline Due to Failure
                 node_shutdown_manually 
                                 Node Shutdown Manually
                 unknown         Node state unknown
COMMENT

  my $nodesTotal    = 0;
  my $nodesFailed   = 0;
  my $nodesDegraded = 0;
  my $strOut          = "OK! ";
  my $strOutFailed    = "CRITICAL! nodes in FAILED status   (check 'shownode -state'): ";
  my $strOutDegraded  = "WARNING!  nodes in DEGRADED status (check 'shownode -state'): ";
  my $strOutMissing   = "CRITICAL! a node is missing. Check your configuration.";

  $out[3] =~ s/^\s*----+.*//gms;
  my @res = split("\n", $out[3]);
  foreach my $i (2..$#res){
    next if($res[$i] =~ /^\s*$/);
    $res[$i] =~ /^\s*(\d+)\s+(\w+)\s+(.*?)\s*$/;

    if(lc($2) eq "failed"){
      $strOutFailed .= "$1 ($3), ";
      $nodesFailed++;
    }
    elsif(lc($2) eq "degraded"){
      $strOutDegraded .= "$1 ($3), ";
      $nodesDegraded++;
    }
    else{}
    $nodesTotal++;
  }
  $strOut .= $nodesTotal." nodes online.";
  $returnState = 'OK';

  if($nodesFailed   > 0){
    $strOut =  $strOutFailed;
    $returnState = 'CRITICAL';
  }
  if($nodesDegraded > 0){
    $strOut =  $strOutDegraded;
    $returnState = 'WARNING';
  }
  if($nodesFailed   > 0 && $nodesDegraded > 0){
    $strOut =  $strOutFailed.$strOutDegraded;
    $returnState = 'CRITICAL';
  }
  #if($nodesTotal < $countNodes){
  #  $strOut =  $strOutMissing;
  #  $returnState = 'CRITICAL';
  #}

  print "$strOut\n";
  $exp->soft_close();
  exit $returnCodes{$returnState};
}
elsif($checkCommand eq "check_vv"){

=pod

#> B<check_3par.pl> check_vv 3par-sp.mycompany.net monitor monitor123

Output:

 OK! 130 VVs online.
 CRITICAL! VVs in FAILED status   (check 'showvv -state'): 7 (fc_vol.1),
 WARNING!  VVs in DEGRADED status (check 'showvv -state'): 1 (.srdata),
 CRITICAL! VVs in FAILED status   (check 'showvv -state'): 7 (fc_vol.1), 8 (fc_vol.2), WARNING!  VVs in DEGRADED status (check 'showvv -state'): 1 (.srdata), 9 (fc_vol.3),
 7 (fc_vol.1) => VV_ID (VV_NAME)

=cut

<<'COMMENT';
#> showvv -showcols Id,Name,State 

 Id           VV identifier
 Name         VV name
 State        State of the VV is one of
                 normal     VV is operating normally
                 failed     VV is operating abnormally
                 degraded   VV is in degraded state
COMMENT

  my $vvsTotal    = 0;
  my $vvsFailed   = 0;
  my $vvsDegraded = 0;
  my $strOut          = "OK! ";
  my $strOutFailed    = "CRITICAL! VVs in FAILED status   (check 'showvv -state'): ";
  my $strOutDegraded  = "WARNING!  VVs in DEGRADED status (check 'showvv -state'): ";

  $out[3] =~ s/^\s*----+.*//gms;
  my @res = split("\n", $out[3]);
  foreach my $i (2..$#res){
    next if($res[$i] =~ /^\s*$/);
    #print "item: ->$res[$i]<-\n";
    $res[$i] =~ /^\s*(\d+)\s+(.*?)\s+(.*?)\s*$/;
    #print "\$1:$1,\$2:$2,\$3:$3,\n";

    if(lc($3) eq "failed"){
      $strOutFailed .= "$1 ($2), ";
      $vvsFailed++;
    }
    elsif(lc($3) eq "degraded"){
      $strOutDegraded .= "$1 ($2), ";
      $vvsDegraded++;
    }
    else{}
    $vvsTotal++;
  }
  $strOut .= $vvsTotal." VVs online.";
  $returnState = 'OK';

  if($vvsFailed   > 0){
    $strOut     =  $strOutFailed;
    $returnState = 'CRITICAL';
  }
  if($vvsDegraded > 0){
    $strOut     =  $strOutDegraded;
    $returnState = 'WARNING';
  }
  if($vvsFailed   > 0 && $vvsDegraded > 0){
    $strOut     =  $strOutFailed.$strOutDegraded;
    $returnState = 'CRITICAL';
  }

  print "$strOut\n";
  $exp->soft_close();
  exit $returnCodes{$returnState};
}
elsif($checkCommand eq "showalert"){

=pod

#> B<check_3par.pl> showalert 3par-sp.mycompany.net monitor monitor123

Output:

 OK! No new alerts.
 CRITICAL! Alerts with severity Fatal, Critical or Major (check 'showalert -n'),
 WARNING!  Alerts with severity DEGRADED (check 'showalert -n'),

=cut

<<'COMMENT';
#> showalert -n

  Id          : 219
  State       : New
  Message Code: 0x0450001
  Time        : 2017-11-29 09:12:08 CET
  Severity    : Major
  Type        : Data Cache DIMM CECC Monitoring
  Message     : Node 1, Data Cache DIMM 0.1.0 is failing. Correctable ECC limit exceeded.

COMMENT

  my $alertsTotal    = 0;
  my $nodesFailed   = 0;
  my $nodesDegraded = 0;
  my $strOut          = "OK! No Alerts.";
  my $strOutFailed    = "CRITICAL! Alerts with severity Fatal, Critical or Major (check 'showalert -n'): ";
  my $strOutDegraded  = "WARNING!  Alerts with severity DEGRADED (check 'showalert -n'): ";

  $out[3] =~ s/^\s*----+.*//gms;

  $returnState = 'OK';
  if($out[3] =~ /\nState\s+:\s+New/i && $out[3] =~ /Severity\s+:\s+Fatal|Critical|Major/i){
    $strOut =  $strOutFailed." ".$out[3];
    $returnState = 'CRITICAL';
  }
  elsif($out[3] =~ /State\s+:\s+New/i && $out[3] =~ /Severity\s+:\s+Degraded/i){
    $strOut =  $strOutDegraded." ".$out[3];
    $returnState = 'WARNING';
  }

  print "$strOut\n";
  $exp->soft_close();
  exit $returnCodes{$returnState};
}
else{
  print "Incorrect usage (invalid CHECK_COMMAND): check_3par.pl CHECK_COMMAND [3PAR_IP/NAME] [USER] [PASS]\n";
  print "commands:\n".join( "\n", keys(%checkCommands))."\n";
  $exp->soft_close();
  exit $returnCodes{'CRITICAL'};
}

$exp->soft_close();