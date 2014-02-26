use POSIX qw(strftime);
use UPnP::ControlPoint;
use UPnP::Common;
use Class::Inspector;
use Data::Dumper;
use strict;
use Term::ANSIColor;
use Time::HiRes qw(gettimeofday);
use Time::Local;
use LWP::UserAgent;
use Storable;


system('clear');


print color("green"), "**************************************\n", color("reset");
print color("green"), "*                                    *\n", color("reset");
print color("green"), "*         Sensor Device v1.4         *\n", color("reset");
print color("green"), "*                                    *\n", color("reset");
print color("green"), "*    Belkin WeMo Device Listener     *\n", color("reset");
print color("green"), "*                                    *\n", color("reset");
print color("green"), "**************************************\n\n", color("reset");

print(printDate() . " \nSearching for WeMo Devices...\n");
sendPushover("WeMo Listener Started.\n" . printDate());

my $friendlyHash = retrieve('friendlyHash') if -e "friendlyHash";
my $stateHash = retrieve('stateHash') if -e "stateHash";
if ($stateHash eq "") {$stateHash= {}};
if ($friendlyHash eq "") {$friendlyHash= {}};


my $activityHash = {};
my $lastMotionHash = {};
my $lastDate=0;
my $minuteStep = 1;

my $durationStep = 5; #seconds
my $motionGapMax = 21;
my $motionGapMin = 4;

my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);

my $cp = UPnP::ControlPoint->new;
my $searchControllee = $cp->searchByType("urn:Belkin:device:controllee:1",\&callback);
my $searchSensor = $cp->searchByType("urn:Belkin:device:sensor:1",\&callback);


$cp->handle;

sub handleSequence{
	my $secondsOfActivity = shift;
	my $motionType = shift;
	my $friendlyName = shift;
	my $deviceType = shift;
	
   	if ($deviceType eq "sensor"){
		my $now = gettimeofday;
		my $previousMotionFound = $lastMotionHash->{_lastMotionFound};
		my $previousMotionStamp = $lastMotionHash->{_lastMotionStamp};
		my $previousMotionType = $lastMotionHash->{_lastMotionType};
		
		my $motionGapDuration = int(($now - $previousMotionStamp) / $durationStep) * $durationStep + $durationStep;
				
		if ( $previousMotionFound ne $friendlyName && $previousMotionFound ne "" && $friendlyName ne ""){
			if ($motionGapDuration < $motionGapMax && $motionGapDuration > $motionGapMin && $previousMotionType == 0 && $motionType == 1 ){
				my $addCommentLine = "SEQ_MOTION [" . $previousMotionFound . "] to [" .  $friendlyName . "] in less than " . $motionGapDuration . " secs.";
				print color("blue"), $addCommentLine , color("reset"), "\n";
				sendPushover("Travel from " . $previousMotionFound . " to " . $friendlyName );
			}
		}

		$lastMotionHash->{_lastMotionStamp} = $now;
		$lastMotionHash->{_lastMotionFound} = $friendlyName;
		$lastMotionHash->{_lastMotionType} = $motionType;
	}
}

sub printDate{
 	my $date = localtime;
	return strftime('%a %I:%M:%S',localtime());
}

sub updateDatabaseStorage{
	# ************************** Now Write a readable CSV **************************
	my $content="";
	
	my $doubleCheckDatabase={};

	while (my ($baseAddress, $baseAddressHash) = each %$friendlyHash) {
			my $deviceName = $baseAddressHash->{_name};
			my $deviceType = $baseAddressHash->{_type};
			my $deviceState =$baseAddressHash->{_binary} == 1? $deviceType . "_on": $deviceType . "_off";
			my $ipAddress;
			($ipAddress)= $baseAddress =~ /http:\/\/(.*)\//;
		
			$content=$content . "<div id='$deviceName-$deviceType' class='$deviceState' onclick=\"toggleState(this);\">$deviceName</div>\n";
	}
	open (LOGFILE, '> /home/pi/nodejs/wemo.html') || warn "Could not open $!";
	print LOGFILE $content , "\n";
	close (LOGFILE);

        store $friendlyHash, 'friendlyHash';
        store $stateHash, 'stateHash';
}

sub eventCallback {

	my ($service, %properties) = @_;
	my $didChange=0;
	while (my ($key, $val) = each %properties) {
		
		if ($key eq 'BinaryState'){
			my $date = printDate();
			my $friendlyName = $friendlyHash->{$service->{BASE}}->{_name};
			my $binaryState = $friendlyHash->{$service->{BASE}}->{_binary};
			my $lastBinaryOn = $friendlyHash->{$service->{BASE}}->{_lastBinaryOn};
			my $lastBinaryOff = $friendlyHash->{$service->{BASE}}->{_lastBinaryOff};
			$stateHash->{$friendlyHash->{$service->{BASE}}->{_type}}->{$friendlyName} = $binaryState;
			
			if ($val eq 1 && $binaryState eq 0){
				$friendlyHash->{$service->{BASE}}->{_binary} = 1;
				$friendlyHash->{$service->{BASE}}->{_lastBinaryOn} = gettimeofday;
				
				$lastBinaryOn = gettimeofday;
				my $differential = sprintf("%.2f",$friendlyHash->{$service->{BASE}}->{_lastBinaryOn} - $lastBinaryOff);
				my $logline = "BINARY_ON \t$date\t" .  $friendlyName . "\t RESTED " . $differential . " secs";
				print color("green"), $logline , color("reset"), "\n";
				
				if ($differential > 600){
					my $pushoverMessage = index($friendlyHash->{$service->{BASE}}->{_type} ,"sensor") == -1 ? $friendlyName . " powered on." : "Motion at " .  $friendlyName;
					sendPushover($pushoverMessage . "\n" . $date);
				}
				$friendlyHash->{$service->{BASE}}->{_lastInterStateDuration}=$differential;
				$friendlyHash->{$service->{BASE}}->{_lastInterState}=0;
				$didChange=1;
				handleSequence($differential, "1" , $friendlyName,$friendlyHash->{$service->{BASE}}->{_type});
				
			}else{
				if ($binaryState eq 1 && $val eq 0){
					$friendlyHash->{$service->{BASE}}->{_binary} = 0;
					$friendlyHash->{$service->{BASE}}->{_lastBinaryOff} = gettimeofday;
					
					my $differential = sprintf("%.2f",$friendlyHash->{$service->{BASE}}->{_lastBinaryOff} - $lastBinaryOn);
					
					$friendlyHash->{$service->{BASE}}->{_lastInterStateDuration}=$differential;
					$friendlyHash->{$service->{BASE}}->{_lastInterState}=1;

	                                $didChange=1;

					my $logline = "BINARY_OFF \t$date\t" .  $friendlyName . "\t ACTIVE " . $differential ." secs";
					print color("yellow"),$logline ,color("reset"), "\n";
					logActivity($differential, $lastBinaryOn, $friendlyName,$friendlyHash->{$service->{BASE}}->{_type});
					handleSequence($differential, "0", $friendlyName,$friendlyHash->{$service->{BASE}}->{_type});
					
				}elsif ($val eq 0){
					
					$friendlyHash->{$service->{BASE}}->{_binary} = 0;
				}
			}
		}
	}
	if ($didChange ==1 ) {updateDatabaseStorage()};
}

sub callback {
	my ($search, $device, $action) = @_;
	my $date = printDate();
	my $didChange=0;
	
	my $mode="Discovered";
	
	if ($action eq 'deviceAdded') {
		for my $service ($device->services) {
			if (index($service->serviceType, 'basicevent') != -1){
				my $time = gettimeofday;
			
				if ($friendlyHash->{$service->{BASE}}->{_name} eq ""){
					$friendlyHash->{$service->{BASE}}->{_name} = $device->friendlyName;
					$friendlyHash->{$service->{BASE}}->{_type} = index($device->deviceType,"sensor")==-1?"controllee":"sensor";
					$friendlyHash->{$service->{BASE}}->{_binary} = 0;
					$friendlyHash->{$service->{BASE}}->{_lastBinaryOn} = $time;
					$friendlyHash->{$service->{BASE}}->{_lastBinaryOff} =$time;
					$friendlyHash->{$service->{BASE}}->{_lastInterStateDuration} = 0;
					$friendlyHash->{$service->{BASE}}->{_lastInterState} = "Off";
					$didChange=1;
				}else{
					$mode="Renewed";
				}
				
				my $subscription = $service->subscribe(\&eventCallback);
				logActivity(-1,$time, $device->friendlyName,$friendlyHash->{$service->{BASE}}->{_type});
			}
		}
		print("-> ",printDate()," ", index($device->deviceType,"sensor")==-1?"Controllee":"Sensor" ," $mode: " . $device->friendlyName . "\n");
	}
	elsif ($action eq 'deviceRemoved') {

		
	}else{
		#print("Unknown action name for:" . $device->friendlyName . "\n");
	}
	if ($didChange ==1 ){updateDatabaseStorage()};
}


sub logActivity {
	return;
	
	my $secondsOfActivity = shift;
	my $binaryStartedTimestamp = shift;
	my $friendlyName = shift;
	my $deviceType = shift;
	
	if ($deviceType eq ""){
		$deviceType="controllee";
	}
	
	my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings)  = localtime;
	my $epochUntilMidnightYesterday = timelocal(0,0,0,$dayOfMonth,$month,$yearOffset+1900) . ".00000";
	my $minutesIntoToday = ($binaryStartedTimestamp - $epochUntilMidnightYesterday)/60;
	my $minutￛeBlock = int(int($minutesIntoToday / $minuteStep) * $minuteStep);
	
	my $shouldReset = 0;
	
	my $now = $hour*60+$minute;
	$now = int(int($now/$minuteStep)*$minuteStep);
	
	if ($lastDate == $dayOfMonth){
		my $maximumSecondsOfActivity = 60*$minuteStep;
		my $numberAlreadyActive = $activityHash->{$friendlyName}->{$minuteBlock};
		my $numberOfSteps = ($numberAlreadyActive+$secondsOfActivity)/($minuteStep*60);
		if ($numberOfSteps>1) {
			my $numberOfCalculatedSteps = int($numberOfSteps);
			for (my $blockStart = 0; $blockStart < $numberOfCalculatedSteps; $blockStart ++){
				my $maxBlock = $minuteBlock + $blockStart * $minuteStep ;
				$activityHash->{$friendlyName}->{$maxBlock } = $maximumSecondsOfActivity;
			}
			$activityHash->{$friendlyName}->{($minuteBlock + $numberOfCalculatedSteps * $minuteStep)} = ($numberAlreadyActive + $secondsOfActivity) % ($minuteStep*60);
			
		}else{
			$activityHash->{$friendlyName}->{$minuteBlock}+= $secondsOfActivity;
		}
		
	}else{
		$shouldReset = 1;
		$lastDate = $dayOfMonth;
		$activityHash->{$friendlyName}->{$minuteBlock} = $secondsOfActivity;
	}
	
	$activityHash->{$friendlyName}->{_name} = $friendlyName;
	$activityHash->{$friendlyName}->{_type} = $deviceType;
	
	return;
	
	my $fileName = join (" ", $weekDays[$dayOfWeek], $months[$month], $dayOfMonth, $yearOffset + 1900);
	my $logContent = "Time,";
	
	while ( my ($key, $value) = each(%$activityHash) ) {
		if ($activityHash->{$key}->{_type} eq $deviceType){
			$logContent .= "\"" . $activityHash->{$key}->{_name} . "\""  . ",";
		}
	}
	
	$logContent =~ s/,$//;
	
	for (my $block; $block<(1440+$minuteStep); $block+=$minuteStep){
		$logContent .= "\n";
		my $timePrintFormat = $block * 60 + $epochUntilMidnightYesterday ;#sprintf("%02.0f", int($block/60)) . sprintf("%02.0f", int($block % 60));
		$logContent .= $timePrintFormat . ",";
		for (keys %$activityHash){
			if ($activityHash->{$_}->{_type} eq $deviceType){
				if ($shouldReset && $block ne $minuteBlock){
					$activityHash -> {$_}->{$block} = 0;
				}
				my $value = $activityHash->{$_}->{$block};
				$logContent .= sprintf("%.3f",$value) . ",";
			}
		}
		$logContent =~ s/,$//g;
	}
	
	$logContent =~ s/,$//;
	
	if ($deviceType ne ""){
		#write to apache
		#open (LOGFILE, '> /var/www/' . $deviceType . '.csv') || warn "Could not open $!";
		#print LOGFILE $logContent, "\n";
		#close (LOGFILE);
	}
}

sub sendPushover{
	my $message = shift;
	if ($message ne ""){
		
		LWP::UserAgent->new()->post(
  		"https://api.pushover.net/1/messages.json", [
		"token" => "iIrKNmbnA45b9JCT3S0KtCNBQH3bC8",
		"user" => "oMpBEUgLL5djk8D0RqB4HB1TeqyzFz",
		"message" => $message,
		"title" => "WeMo",
		"url" => "http://67.165.232.34/",
		"url_title" => "View Activity",
		]
		);
	}
}

