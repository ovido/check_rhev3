<?php
#
# Plugin: check_rhev3
# Author: Rene Koch <rkoch@rk-it.at>
# Created: 2012/08/14
# Last update: 2015/02/07
#

if ($NAME[1] == "cpu"){

  # process CPU statistics
  $opt[1] = "--vertical-label \"CPU utilization\" -l 0 --title \"CPU utilization for $hostname\" --slope-mode -u 100 -N";
  $def[1]  = "DEF:var1=$RRDFILE[1]:$DS[1]:AVERAGE ";
  $def[1] .= "DEF:var2=$RRDFILE[1]:$DS[2]:AVERAGE ";
  $def[1] .= "DEF:var3=$RRDFILE[1]:$DS[3]:AVERAGE ";

  if ($NAME[2] == "cpu.current.user"){

    # process hypervisor CPU stats
    $def[1] .= "DEF:var4=$RRDFILE[1]:$DS[4]:AVERAGE ";
    $def[1] .= "CDEF:sp2=var2 ";
    $def[1] .= "CDEF:sp3=var3 ";
    $def[1] .= "CDEF:sp4=var4 ";

    $def[1] .= "AREA:sp2#000080:\"User    \" ";
    $def[1] .= "GPRINT:sp2:LAST:\"last\: %3.4lg$UNIT[1] \" ";
    $def[1] .= "GPRINT:sp2:MAX:\"max\: %3.4lg$UNIT[1] \" ";
    $def[1] .= "GPRINT:sp2:AVERAGE:\"average\: %3.4lg$UNIT[1] \"\\n ";
    $def[1] .= "STACK:sp3#FFCC00:\"System  \" ";
    $def[1] .= "GPRINT:sp3:LAST:\"last\: %3.4lg$UNIT[1] \" ";
    $def[1] .= "GPRINT:sp3:MAX:\"max\: %3.4lg$UNIT[1] \" ";
    $def[1] .= "GPRINT:sp3:AVERAGE:\"average\: %3.4lg$UNIT[1] \"\\n ";
    $def[1] .= "STACK:sp4#CCCCCC:\"Idle    \" ";
    $def[1] .= "GPRINT:sp4:LAST:\"last\: %3.4lg$UNIT[1] \" ";
    $def[1] .= "GPRINT:sp4:MAX:\"max\: %3.4lg$UNIT[1] \" ";
    $def[1] .= "GPRINT:sp4:AVERAGE:\"average\: %3.4lg$UNIT[1] \"\\n ";

  }else{

    # process VM CPU stats
    $def[1] .= "CDEF:sp1=100,var1,- ";
    $def[1] .= "CDEF:sp2=var1 ";
    $def[1] .= "CDEF:sp3=var3 ";

    $def[1] .= "AREA:sp2#000080:\"Guest      \" ";
    $def[1] .= "GPRINT:sp2:LAST:\"last\: %3.4lg$UNIT[1] \" ";
    $def[1] .= "GPRINT:sp2:MAX:\"max\: %3.4lg$UNIT[1] \" ";
    $def[1] .= "GPRINT:sp2:AVERAGE:\"average\: %3.4lg$UNIT[1] \"\\n ";
    $def[1] .= "STACK:sp3#FFCC00:\"Hypervisor \" ";
    $def[1] .= "GPRINT:sp3:LAST:\"last\: %3.4lg$UNIT[1] \" ";
    $def[1] .= "GPRINT:sp3:MAX:\"max\: %3.4lg$UNIT[1] \" ";
    $def[1] .= "GPRINT:sp3:AVERAGE:\"average\: %3.4lg$UNIT[1] \"\\n ";
    $def[1] .= "STACK:sp1#CCCCCC:\"Idle       \" ";
    $def[1] .= "GPRINT:sp1:LAST:\"last\: %3.4lg$UNIT[1] \" ";
    $def[1] .= "GPRINT:sp1:MAX:\"max\: %3.4lg$UNIT[1] \" ";
    $def[1] .= "GPRINT:sp1:AVERAGE:\"average\: %3.4lg$UNIT[1] \"\\n ";

  }

}elseif (preg_match("/traffic/i",$NAME[1])){

  # proccess network traffic
  $opt[1] = "--vertical-label \"Traffic usage\" -l 0 --title \"Traffic utilization for $hostname\" --slope-mode -N";
  $def[1] = "";

  foreach ($this->DS as $key=>$val){
    $ds = $val['DS'];
    $def[1] .= "DEF:var$key=$RRDFILE[$ds]:$ds:AVERAGE ";
    $def[1] .= "CDEF:traffic$key=var$key,8,* ";
    $def[1] .= "LINE1:traffic$key#" . color() . ":\"" . substr($LABEL[$ds],8) ."      \" ";
    $def[1] .= "GPRINT:traffic$key:LAST:\"last\: %3.4lgMbit/s \" ";
    $def[1] .= "GPRINT:traffic$key:MAX:\"max\: %3.4lgMbit/s \" ";
    $def[1] .= "GPRINT:traffic$key:AVERAGE:\"average\: %3.4lgMbit/s \"\\n ";
  }

}elseif (preg_match("/_up/i", $NAME[1])){
	
  # process service status
  $opt[1] = "--vertical-label \"" . str_replace('_up', '', $NAME[1]) . " status\" --slope-mode -N";
  $def[1] = "";
  
  foreach ($this->DS as $key=>$val){
  	$components = array("Datacenters_", "Clusters_", "Hosts_", "Vms_", "Storagedomains_");
  	$ds = $val['DS'];
  	$def[1] .= "DEF:var$key=$RRDFILE[$ds]:$ds:AVERAGE ";
  	$def[1] .= "LINE1:var$key#" . color() . ":\"" . str_replace($components, '', $LABEL[$ds]) . "     \" ";
  	$def[1] .= "GPRINT:var$key:LAST:\"last\: %3.4lg \" ";
  	$def[1] .= "GPRINT:var$key:MAX:\"max\: %3.4lg \" ";
  	$def[1] .= "GPRINT:var$key:AVERAGE:\"average\: %3.4lg \"\\n ";
  }

}elseif (preg_match("/storage_/i", $NAME[1])){

  # process storage domain usage
  $opt[1] = "--vertical-label \"" . "Storage usage\" --slope-mode -N";
  $def[1] = "";

  foreach ($this->DS as $key=>$val){
  	$ds = $val['DS'];
  	$def[1] .= "DEF:var$key=$RRDFILE[$ds]:$ds:AVERAGE ";
  	$def[1] .= "LINE1:var$key#" . color() . ":\"" . str_replace('storage_', '', $LABEL[$ds]) . "     \" ";
  	$def[1] .= "GPRINT:var$key:LAST:\"last\: %3.4lg \" ";
  	$def[1] .= "GPRINT:var$key:MAX:\"max\: %3.4lg \" ";
  	$def[1] .= "GPRINT:var$key:AVERAGE:\"average\: %3.4lg \"\\n ";
  }

}else{

  # process load, ksm, memory and swap statistics
  if ($NAME[1] == "ksm.cpu.current"){
    $opt[1] = "--vertical-label \"KSM utilization\" -l 0 --title \"KSM utilization for $hostname\" --slope-mode -u 100 -N";
  }elseif ($NAME[1] == "cpu.load.avg.5m"){
    $opt[1] = "--vertical-label \"load utilization\" -l 0 --title \"Load utilization for $hostname\" --slope-mode -N";
  }elseif ($NAME[1] == "memory"){
    $opt[1] = "--vertical-label \"Memory\" -l 0 --title \"Memory utilization for $hostname\" --slope-mode -u 100 -N";
  }elseif ($NAME[1] == "swap"){
    $opt[1] = "--vertical-label \"Swap\" -l 0 --title \"Swap utilization for $hostname\" --slope-mode -u 100 -N";
  }elseif (($NAME[1] == "Hosts") || ($NAME[1] == "hosts")){
    $opt[1] = "--vertical-label \"Hosts up\" -l 0 --title \"Hosts with status UP\" --slope-mode -N";
  }elseif ($NAME[1] == "nics"){
    $opt[1] = "--vertical-label \"NICs active\" -l 0 --title \"NICs with status Active\" --slope-mode -N";
  }elseif ($NAME[1] == "networks"){
    $opt[1] = "--vertical-label \"Networks operational\" -l 0 --title \"Networks with status Operational\" --slope-mode -N";
  }elseif ($NAME[1] == "Datacenters"){
    $opt[1] = "--vertical-label \"Datacenters up\" -l 0 --title \"Datacenters with status UP\" --slope-mode -N";
  }elseif ($NAME[1] == "storagedomains"){
    $opt[1] = "--vertical-label \"Storagedomains active\" -l 0 --title \"Storagedomains with status Active\" --slope-mode -N";
  }elseif ($NAME[1] == "vmpool"){
    $opt[1] = "--vertical-label \"VMs up\" -l 0 --title \"VMs used in Pool\" --slope-mode -N";
  }elseif ($NAME[1] == "Vms"){
    $opt[1] = "--vertical-label \"VMs up\" -l 0 --title \"VMs with status UP\" --slope-mode -N";
  }elseif (preg_match("/storage_/i",$NAME[1])){
    $opt[1] = "--vertical-label \"Disk utilization\" -l 0 --title \"Storage utilization\" --slope-mode -u 100 -N";
  }else{
    $opt[1] = "--vertical-label \"" . strtoupper($NAME[1]) . "\" -l 0 --title \"" . strtoupper($NAME[1]) . " utilization for $hostname\" --slope-mode -N";
  }

  if ( ($NAME[1] == "ksm.cpu.current") || ($NAME[1] == "memory") || ($NAME[1] == "cpu.load.avg.5m") || ($NAME[1] == "swap") ){

    $def[1]  = "DEF:var1=$RRDFILE[1]:$DS[1]:AVERAGE ";
    $def[1] .= "CDEF:sp1=var1,100,/,12,* ";
    $def[1] .= "CDEF:sp2=var1,100,/,30,* ";
    $def[1] .= "CDEF:sp3=var1,100,/,50,* ";
    $def[1] .= "CDEF:sp4=var1,100,/,70,* ";

    $def[1] .= "AREA:var1#FF5C00:\"$NAME[1]    \" ";
    $def[1] .= "AREA:sp4#FF7C00: ";
    $def[1] .= "AREA:sp3#FF9C00: ";
    $def[1] .= "AREA:sp2#FFBC00: ";
    $def[1] .= "AREA:sp1#FFDC00: ";

    $def[1] .= "GPRINT:var1:LAST:\"last\: %3.4lg$UNIT[1] \" ";
    $def[1] .= "GPRINT:var1:MAX:\"max\: %3.4lg$UNIT[1] \" ";
    $def[1] .= "GPRINT:var1:AVERAGE:\"average\: %3.4lg$UNIT[1] \" ";
    $def[1] .= "LINE1:var1#000000: ";

  }else{

    $def[1]  = "DEF:var1=$RRDFILE[1]:$DS[1]:AVERAGE ";
    $def[1] .= "LINE1:var1#000000:\"" . $NAME[1] . "     \" ";
    $def[1] .= "GPRINT:var1:LAST:\"last\: %3.4lg$UNIT[1] \" ";
    $def[1] .= "GPRINT:var1:MAX:\"max\: %3.4lg$UNIT[1] \" ";
    $def[1] .= "GPRINT:var1:AVERAGE:\"average\: %3.4lg$UNIT[1] \"\\n ";

  }

}


# generate html color code
function color(){
  $color = dechex(rand(0,10000000));
  while (strlen($color) < 6){
    $color = dechex(rand(0,10000000));
  }
  return $color;
}

?>
