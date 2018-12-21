# This script opens the EBS SW Components Excel sheet and parses a given program column.
# It will parse the specific column looking for "yes" words indicating that a component is used.
# Empty cells or not proper cells (containing number instead of string or vica versa) are not considered.
# The script collects the MKS RM IDs in a list, which could contain duplicates.
# This script removes the duplicated document numbers.

#!/usr/bin/perl -w
use warnings;
use strict;
use Cwd;

use File::Basename;
##########################use Spreadsheet::ParseExcel;  # For parsing Excel files
#use Spreadsheet::XLSX;        # http://search.cpan.org/~dmow/Spreadsheet-XLSX-0.13-withoutworldwriteables/lib/Spreadsheet/XLSX.pm
use Excel::Writer::XLSX;      # For creating Excel files
#use Speadsheet::ParseExcel;
use Scalar::Util qw(looks_like_number); # To check if a value is an integer or string
use POSIX qw(strftime);       # for handling and printing time
use Time::HiRes qw[gettimeofday tv_interval];  # for elapsed time
use constant MAX_ROW => 2000;
use constant MAX_COL => 2000;
use Term::ReadKey;
#use Win32::GUI();
use Data::Dumper;

my $counter = 0;            # Variable for counting the items
my $char;      # Observing Keypress
my $column;    # For selecting the proper column in the Excel sheet
my $row;
my $start_run = time(); # Counting the runtime
my $end_run;            # Counting the runtime
my $run_time;           # Counting the runtime
my $converted_time;     # Counting the runtime
my $sheet_name;
my $Layer_cell;
my $Cluster_cell;
my $RM_Doc_cell;
my $Chosen_cell;
my $one_cluster;
my $one_layer;
my $one_RM_doc;
my $chosen;
my @RM_doc_ids;            # Array for RM doc IDs
my @RM_doc_ids_filtered;   # Array without duplicates
#my $excel = Spreadsheet::XLSX -> new ('EBS SW Components.xlsx');
my $i;
my $x;
my $temp_file = "RQ_run_results.txt";  # Temporary file for observing nested RM IDs
my $directory = "";     # Variable to create folders
my $one_RM_doc_id;      # Index (running) variable for processing several RM documents
my $filename;           # Variable for storing file names
my $one_id;             # Index (running) variable for processing several RM items
my @New_IDs;            # Array for the newly found items
my $one_item;           # Variable for one item
my $sec;                # Helper variable for printing the current time (seconds)
my $min;                # Helper variable for printing the current time (minutes)
my $hour;               # Helper variable for printing the current time (hours)
my $mday;               # Helper variable for printing the current time ()
my $mon;                # Helper variable for printing the current time (month)
my $year;               # Helper variable for printing the current time (year)
my $wday;               # Helper variable for printing the current time ()
my $yday;               # Helper variable for printing the current time ()
my $isdst;              # Helper variable for printing the current time ()
my $total_nr_of_items=0;# Total number of processed items
my $efficiency;         # Measure of efficiency (nr of requirements/items process within 1s)
my $data;
my $asil;            # Variable for MKS field: ASIL
my $RM_Doc_ID; 
my $ID;           
my $component;            
my $one_line;
my $one_path;
my @lines;
my @array;
my @DocInfoArray;
my @SRS3DocInfoArray;
my @DocArray;
my @SRS3Array;
my $SRS3category; 
my $SRS3asil; 
my $SRS3ID;
my $SRS3RM_Doc_ID;
my $SRS3component;
my $category;        # Variable for MKS field: Category
my $SW_Req_counter;  # Counting the SW requirements
my @excelarray;
my $colcounter = 7;
my $rowcounter = 4;
my $mks_command;		# Connecting to MKS1
#my @ASILOnlyArray;
my @ASILarray;
my $role;
my $k;
my $j;
my $l;
my $one_EBS_subcomponent;
my $description_one_line;
my @file_lines;
my $one_file;
my @CompASILarray;
my $SWArch_Query = '';  
my $project_id = '';          # Continental Project ID
my $vehicle_platform = ''; 
my $SRS3shorthandcomponent;

sub list # Collects file (paths) recursively
{

  my ($dir) = @_;
  return unless -d $dir;
  my @files;
  if (opendir my $dh, $dir)
  {    # Capture entries first, so we don't descend with an open dir handle.
    my @list;
    my $file;
    while ($file = readdir $dh) { push(@list, $file); }
    closedir($dh);
    for $file (@list)
    {
      # Unix file system considerations.
      next if $file eq '.' || $file eq '..';
      # Swap these two lines to follow symbolic links into directories.  Handles circular links by entering an infinite loop.
      if($file ne basename($0)) # don't list the running script
      {
         push @files, "$dir/$file"        if -f "$dir/$file";
         push @files, list ("$dir/$file") if -d "$dir/$file";
         $counter++;
      }
      print "Files found: ".$counter."\r";
    }
  }
  return @files;			#all files in folder
}

sub ExcelWrite{
 
	#print "%%%%%%%%%%%%%\n";
#use Excel::Writer::XLSX;
 #sprintf("RQs_%04d.%02d.%02d.%02d.%02d.%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec); ?????
	#|  SW PART  |  SW CLUST  |  SW COMP  |  ASIL  |  RMID  |  SW COMP  |  ASIL  |  RMID  |
	#|    B4 	 | 	   C4     |    D4     |   E4   |   F4   |    G4     |   H4   |   I4   |
	print "Excel File is now being written \n";
	
	#my $workbook  = Excel::Writer::XLSX->new( 'd:\casdev\sbxs\ffm-mks3\archives\projectdocs\AH_ControlDocs\project.pj\AH_Software_Architecture\03.MandatoryWorkProducts\03.SWArchTraceRec\01.ReqMetricReport\TB2013\simple.xlsx');
	my $workbook  = Excel::Writer::XLSX->new( 'ASIL_Report.xlsx');
	my $worksheet = $workbook->add_worksheet();
	
	my $SRS3Format = $workbook->add_format();
	$SRS3Format ->set_bg_color('#33CCCC');
	my $DesignFormat = $workbook->add_format();
	$DesignFormat ->set_bg_color('#339966');
	my $BreakFormat = $workbook->add_format();
	$BreakFormat ->set_bg_color('black');
	my $StructureFormat = $workbook->add_format();
	$StructureFormat ->set_bg_color('#D4D46C');
	my $WhiteFormat = $workbook ->add_format();
	$WhiteFormat -> set_bg_color('white');
	
	$worksheet->set_column('B:C',20, $StructureFormat);
	$worksheet->set_column('D:F',20, $SRS3Format);
	$worksheet->set_column('H:H',30, $DesignFormat);
	$worksheet->set_column('I:K',20, $DesignFormat);
	$worksheet->set_column('G:G',5, $BreakFormat);
	$worksheet->set_row('1',7, $BreakFormat); 
	$worksheet->set_row('3',7, $BreakFormat); 
	$worksheet->set_column('A:A',7, $BreakFormat);
	$worksheet->set_column('K:K',7, $BreakFormat);
	$worksheet->set_row('0',15, $WhiteFormat); 
	
	$worksheet->write("B1", "Continental AG");
	$worksheet->write("C1", "SW Architecture");
	
	#SW Component SRS3
	$worksheet->write("B3", "SW Partition");
	$worksheet->write("C3",  "SW Cluster");  	
	$worksheet->write("D3", "SRS3 SW");
	$worksheet->write("E3",  "MKS RM ID");
	$worksheet->write("F3", "ASIL Level");
	
	#SW Component Design
	$worksheet->write("H3", "SW Component");
	#$worksheet->write("H3",  "Function");	
	$worksheet->write("I3",  "ASIL Level");
	$worksheet->write("J3", "MKS RM ID");
	
	
	#passing arrays byref and unreferencing them
	my ($CompArray_ref , $SRS3Array_ref) = @_;
	@DocArray = @{$CompArray_ref};
	@SRS3Array = @{$SRS3Array_ref};
	
	
	for $i (0 .. $#DocArray )
	{
		if ($colcounter == 7){				#component
		$worksheet->write($rowcounter,$colcounter, $DocArray[$i][0]);
		$colcounter=9;
		}
		if ($colcounter == 9){				#MKS RMID 
		 $worksheet->write($rowcounter,$colcounter, $DocArray[$i][1]);
		}
		$colcounter = 7;
		$rowcounter++;
	}
	$colcounter = 8;
	$rowcounter = 4;
	
	foreach (@CompASILarray)
	{
		$worksheet->write($rowcounter,$colcounter, $_);
		$rowcounter++;
	}

	$i=0;
	$colcounter = 3;
	$rowcounter = 4;
	for $i (0 .. $#SRS3Array )
	{
		if ($colcounter == 3){				#component
		$worksheet->write($rowcounter,$colcounter, $SRS3Array[$i][0]);
		$colcounter++;
		}
		if ($colcounter == 4){				#RMID
		$worksheet->write($rowcounter,$colcounter, $SRS3Array[$i][1]);
		$colcounter = 3;
		}
		$rowcounter++;
	}
	
	$colcounter = 5;
	$rowcounter = 4;
	
	foreach (@ASILarray)
	{
		$worksheet->write($rowcounter,$colcounter, $_);
		$rowcounter++;
	}
	$workbook -> close;
	print "Excel File has been writen to: simple.xlsx"."\n";
}

sub uniq {
   my %seen;
   grep !$seen{$_}++, @_;
}

 sub RM_doc_txt_read {
	# my $filename = 'SWC Detailed MKS Doc ID.txt';
	my @Rm_doc_ids;
	my @filelines;
		#open(input_TXT_FILE, "<",'SWC Detailed MKS Doc ID.txt' ) or die("Can't open file");
		
	###############################################################################
	open(input_TXT_FILE, "<",'compnametest.txt' ) or die("Can't open file");  
	   @filelines = <input_TXT_FILE>;
         close(input_TXT_FILE);
		 foreach (@filelines){
			chomp ($_);
			push( @RM_doc_ids,$_);
			#push( @RM_doc_ids,10038882);
		 }
		 return @RM_doc_ids;
}
##########################################################################################

@RM_doc_ids = RM_doc_txt_read();
@RM_doc_ids = uniq(@RM_doc_ids);
print "Unique MKS Doc IDs from txt file: "."\n";

foreach(@RM_doc_ids){
#print "********************\n";
print $_."\n";
}


#10844881
#11364389
#11364255
#10845575




# 11364389
# 10844881
# 11364255
# 10845575
# 11364604
# 11365193
# 11341121
# 11360846
# 11341121
# 11328300
# 11336995
# 11307962
# 11329691
# 11338139
# 11363136
# 11345027

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();    # Read the current time
  $directory = sprintf("RQs_%04d.%02d.%02d.%02d.%02d.%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
	unless(mkdir $directory) {die "Unable to create $directory\n";}
	print "Files can now be found in $directory"."\n";
	print "This process may take awhile....."."\n";
	chdir($directory) or die "can't chdir $directory\n";
	my $tempcounter;
for $i (0 .. $#RM_doc_ids)  # Process several RM documents after each other
{
	$directory = "RM_Doc_".$RM_doc_ids[$i];
		unless(mkdir $directory) {die "Unable to create folder $directory\n";}
    chdir($directory) or die "can't chdir $directory\n";
	print "Getting information from RM ID ".$RM_doc_ids[$i]."\n";
    $mks_command = `im viewissue $RM_doc_ids[$i]|find "Contains:"`; 
     my @RM_IDs;                         # Temporary array for storing the expansion list
     my @All_Item_IDs;                   # Array used for storing all the RM_IDs
     push(@RM_IDs, $RM_doc_ids[$i]);      # Push one item to the array
     push(@All_Item_IDs, $RM_doc_ids[$i]);# Push one item to the array
	 
	 while ( (scalar @RM_IDs) > 0){   # As long as we have (nested) RM IDs
         $one_id = pop @RM_IDs;                                         # Take one item from the array
         $mks_command = `im viewissue $one_id|find "Contains:"`;        # -> Contains: 16089406ay, 16089393ay, 16089408ay, 16475188ay, 16089403ay, 16089391ay
         $mks_command = substr($mks_command, 10, length($mks_command)); # -> 16089406ay, 16089393ay, 16089408ay, 16475188ay, 16089403ay, 16089391ay
         chomp($mks_command);                                           # Remove the newline character at the end of the string
         @New_IDs = split /, /, $mks_command;                           # Split elements at the comma into a new array
         foreach $one_item (@New_IDs){                 # Go over each of the new items
            $one_item = substr($one_item, 0, -2);     # Remove the last two characters, else the item IDs would result in the form of 16089406ay
            push(@RM_IDs, $one_item);                 # Push the item into an ever growing/shrinking array
            push(@All_Item_IDs, $one_item);           # Push the item into an ever growing/shrinking array
         }
         printf("   Remaining (nested) items: %.5d\r", (scalar @RM_IDs) );
      }
	  print "\n";
	  $counter = scalar @All_Item_IDs;                # Count the number of elements in an array
	 $tempcounter = $counter;
	  while(@All_Item_IDs)                            # Loop through on all MKS RM IDs
      {
        $one_item = shift @All_Item_IDs;             # Take one item from the (beginning of the) list
        $counter--;                                  # Decrease counter for the remaining elements
        $mks_command = `im viewissue $one_item`;     # Pull information from MKS RM about the item
        $filename = "ID_".$one_item.".txt";          # Create file with dynamic filename
        open(LOG_FILE_2,'>',$filename);
        print LOG_FILE_2 $mks_command."\n";
        printf("   Remaining items: %.5d\r", $counter);
	}
	close(LOG_FILE_2);
	
	print "\n";
	
	print "   All extracted RM IDs: ".$tempcounter."\n";
	# print $mks_command;
	# print "\n";
	# print  "RM Doc ".$RM_doc_ids[$i]." ".$mks_command."\n";
	# printf "\n";
      chdir '..' or die "Can't go up one level\n";   
}

@array = list(cwd());
my $HighestASIL = "NOK";


my $comptempID = "";
my $comptempASIL= "";
my $pop;
foreach $one_path (@array)
{	
   if($one_path =~ /^.*\/RM_Doc_(\d*)\/ID_(\d*).txt/) # Recognize pattern in file path: .../RM_Doc_XXXXX/ID_YYYYY.txt
   {
      # Open file
      open(FILE, "<", $one_path) or die("Can't open file");
      @lines = <FILE>;
      close(FILE);
		foreach $one_line (@lines)    # Read file line by line
		{
			if($one_line =~ /^Shared Category:\s(.*)/)      {$category = $1;} #print "$category\n";}
			if($one_line =~ /^Category:\s(.*)/)             {$category = $1;} #print "$category\n";}
			if($one_line =~ /^ASIL:\s(.*)/)                 {$asil = $1;} #print "$asil\n";}
			if($one_line =~ /^Document ID:\s(.*)/)          {$ID = $1;} #print "$ID\n";}
			if($one_line =~ /^Live Item ID:\s(.*)/)         {$RM_Doc_ID = $1;} #print "$RM_Doc_ID\n";}
			if($one_line =~ /^Document Name:\s.*\:(.*)\n$/) {$component = $1;} #print "$component\n";}
		}
		if($category eq "Software Requirement")
		{
			$SW_Req_counter++;
			if ($asil eq "QM")										 {$asil = "NOK";}
			if($asil eq "")                                          {$asil = "NOK";}
			if($asil eq " ")                                         {$asil = "NOK";}
			if($asil eq "\n")                                        {$asil = "NOK";}
			if($asil eq "To be determined")                          {$asil = "NOK";}
			if($asil eq "Safety relevant - ASIL/SIL not determined") {$asil = "NOK";}
			if($asil eq "ASIL A")                                    {$asil = "A ";}
			if($asil eq "ASIL B")                                    {$asil = "B ";}
			if($asil eq "ASIL B (D)")                                {$asil = "B ";}
			if($asil eq "ASIL C")                                    {$asil = "C ";}
			if($asil eq "ASIL D")                                    {$asil = "D ";}
			
			if ($ID ne $comptempID){			#New RMID means push a full new set of information
			
				$HighestASIL = "NOK";
				if ($HighestASIL eq "NOK" and $asil ne "NOK")									{$HighestASIL = $asil;}
				if ($HighestASIL  eq "A " and $asil eq "B " or $asil eq "C " or $asil eq "D ")	{$HighestASIL = $asil;} #????parentheses in statement order of operations??
				if ($HighestASIL eq "B " and $asil eq "C " or $asil eq "D ")					{$HighestASIL = $asil;}
				if ($HighestASIL eq "C " and $asil eq "D " )					   				{$HighestASIL = $asil;}
				push(@DocInfoArray, [$component, $ID]);
				push @CompASILarray,$HighestASIL;
				#reset temp variables
				$comptempID = $ID;
				$comptempASIL= $asil;
				}
				if ($asil ne $comptempASIL)
				{		#Same RMID as previous just needs to pop the asil level and push a new asil level
					
					if ($HighestASIL eq "NOK" and $asil ne "NOK")										{$HighestASIL = $asil;}
					if ($HighestASIL  eq "A " and $asil eq "B " or $asil eq "C " or $asil eq "D " )		{$HighestASIL = $asil;}
					if ($HighestASIL eq "B " and $asil eq "C " or $asil eq "D ")						{$HighestASIL = $asil;}
					if ($HighestASIL eq "C " and $asil eq "D " )					   					{$HighestASIL = $asil;}
					$pop = pop @CompASILarray;
					push @CompASILarray, $HighestASIL;
					$comptempID = $ID;
					$comptempASIL= $asil;
				}
			$component= ""; 
			$asil = ""; 
			$RM_Doc_ID = "";
			$ID = "";
		}	
	}
}


sub Main_Terminate
{
   -1;
}

my $Projectsheet;
my $node = "";
my $project_sheet_found = 0;
# if (defined ($ARGV[0]))
# {
   # $Projectsheet= $ARGV[0];
# }
# else
# {
  # print "Project sheet ID please: ";
  # $Projectsheet = <STDIN>;
 
  # chomp($Projectsheet);
# }
#$Projectsheet = 1499487;

$Projectsheet = 1356285;
# Pull information from Queries from MKS1

$mks_command = `im setprefs --command=connect --nosave server.hostname=ffm-mks3`;
print $mks_command;
$mks_command = `im setprefs --command=connect --nosave server.port=7002`;
print $mks_command;
$mks_command = `im connect --hostname=ffm-mks3 --port=7002 --batch`;
print $mks_command;
print "Getting information from Project sheet ".$Projectsheet."\n";
$mks_command = `im viewissue $Projectsheet`;
print $mks_command;
open(LOG_FILE,'>01.project_information.txt');
print LOG_FILE $mks_command;
close(LOG_FILE);

print "PROCESSING STARTS HERE\n";
open(FILE, "<", "01.project_information.txt") or die("Can't open file");
@lines = <FILE>;
my @lines2 = <FILE>;
chomp(@lines);
chomp(@lines2);
close(FILE);

foreach $one_line (@lines)    # Check if correct project sheet ID is used
{
   if(index($one_line,"Type: Project Sheet") == 0)
   {
      $project_sheet_found = 1;
   }
   if(index($one_line,"Base for Project (Node): ") == 0)
   {
        $node = substr($one_line,25,4);
        print "Node information found: ".$node."\n";
   }
   if(index($one_line,"Project: ") == 0)
   {
      $project_id = substr($one_line,9);
	  print "Project ID found: " . $project_id . "\n";
   }
   if(index($one_line,"Vehicle/ Platform: ") == 0)
   {
      $vehicle_platform = substr($one_line,19);
	  print "Vehicle / Platform found: " . $vehicle_platform . "\n";
   }
}

if($project_sheet_found == 0)
{
   die("Project sheet ID not found... Please enter a valid Project sheet ID!\n");
}

$mks_command = `im setprefs --command=connect --nosave server.hostname=ffm-mks1`;
print $mks_command;
$mks_command = `im setprefs --command=connect --nosave server.port=7002`;
print $mks_command;
$mks_command = `im connect --hostname=ffm-mks1 --port=7002 --batch`;
print $mks_command;

my $query;

# $create_query: Creation of the Query based on Gergely's [SWArch] Query
my $create_query = ''; 
$query = '[SWArch] (ProjectSheet ' . $Projectsheet . ') - All RMDocs for ' . $vehicle_platform . ' (' . $project_id . ')';
my $ProjectFieldQuery = "/Pool/System/MK C1/Component/Software";
$SWArch_Query = 'im createquery --name="' . $query . '" --queryDefinition=\'((not (field["State"] = "CANCELLED")) and (field["Type"] = "RQ_Software Requirement Document") and (field["Project"] = "'. $ProjectFieldQuery .'") and  (field["Summary"] contains "SRS 3 SWC")   )\'';
print 'SWArch_Query: ' . $SWArch_Query . "\n";

$create_query = `im viewquery "$query"`;
if (length($create_query) == 0) # If query doesn't exist, create one
{
  $create_query = `$SWArch_Query`;
}
else
{
  print "Query '" . $query . "' already exists. Creation of new Query not needed.\n" ;
}
my $match_line;

print "Getting information from Query ".$query."\n";
$mks_command = `im issues --fields=ID,Type,State,"RQ_Metric Document Content Count",Summary --query='$query'`;
print $mks_command;
open(LOG_FILE,'>03.query_run_results.txt');
print LOG_FILE $mks_command;
close(LOG_FILE);

open(FILE, "<", "03.query_run_results.txt") or die("Can't open file");
@lines = <FILE>;
close(FILE);

my $safe_nr;
my $type;
my $state;
my $project;
my $RequestedCompletionDate;
my $PlannedCompletionDate;
my $SolveByReleaseLevel;
my $safe_description;

my @list_of_RM_Doc_IDs;


print "RM Doc IDs:\n";
foreach $one_line (@lines)
{
   if($one_line =~ /^(\d+)\t.*/){push(@list_of_RM_Doc_IDs, $1);}#apply regular exp for at least one digit and tab extract one digit
}

for $i (0 .. $#list_of_RM_Doc_IDs)  # Process several RM documents after each other
{
	$directory = "List_of_RM_Doc_".$list_of_RM_Doc_IDs[$i];
		unless(mkdir $directory) {die "Unable to create folder $directory\n";}
    chdir($directory) or die "can't chdir $directory\n";
	print "Getting information from RM ID ".$list_of_RM_Doc_IDs[$i]."\n";
    $mks_command = `im viewissue $list_of_RM_Doc_IDs[$i]|find "Contains:"`; 
     my @RM_IDs2;                         # Temporary array for storing the expansion list
     my @All_Item_IDs2;                   # Array used for storing all the RM_IDs
     push(@RM_IDs2, $list_of_RM_Doc_IDs[$i]);      # Push one item to the array
     push(@All_Item_IDs2, $list_of_RM_Doc_IDs[$i]);# Push one item to the array
	 
	 while ( (scalar @RM_IDs2) > 0){   # As long as we have (nested) RM IDs
         $one_id = pop @RM_IDs2;                                         # Take one item from the array
         $mks_command = `im viewissue $one_id|find "Contains:"`;        # -> Contains: 16089406ay, 16089393ay, 16089408ay, 16475188ay, 16089403ay, 16089391ay
         $mks_command = substr($mks_command, 10, length($mks_command)); # -> 16089406ay, 16089393ay, 16089408ay, 16475188ay, 16089403ay, 16089391ay
         chomp($mks_command);                                           # Remove the newline character at the end of the string
         @New_IDs = split /, /, $mks_command;                           # Split elements at the comma into a new array
         foreach $one_item (@New_IDs){                 # Go over each of the new items
            $one_item = substr($one_item, 0, -2);     # Remove the last two characters, else the item IDs would result in the form of 16089406ay
            push(@RM_IDs2, $one_item);                 # Push the item into an ever growing/shrinking array
            push(@All_Item_IDs2, $one_item);           # Push the item into an ever growing/shrinking array
         }
         printf("   Remaining (nested) items: %.5d\r", (scalar @RM_IDs2) );
      }
	  print "\n";
	  $counter = scalar @All_Item_IDs2;                # Count the number of elements in an array
	 $tempcounter = $counter;
	  while(@All_Item_IDs2)                            # Loop through on all MKS RM IDs
      {
        $one_item = shift @All_Item_IDs2;             # Take one item from the (beginning of the) list
        $counter--;                                  # Decrease counter for the remaining elements
        $mks_command = `im viewissue $one_item`;     # Pull information from MKS RM about the item
        $filename = "ID_".$one_item.".txt";          # Create file with dynamic filename
        open(LOG_FILE_2,'>',$filename);
        print LOG_FILE_2 $mks_command."\n";
        printf("   Remaining items: %.5d\r", $counter);
	}
	close(LOG_FILE_2);
	
	print "\n";
	
	print "   All extracted RM IDs: ".$tempcounter."\n";
	# print $mks_command;
	# print "\n";
	# print  "RM Doc ".$RM_doc_ids[$i]." ".$mks_command."\n";
	# printf "\n";
      chdir '..' or die "Can't go up one level\n";   
}


my @array2;
@array2 = list(cwd());
$SW_Req_counter = 0;
$one_path = 0;
$one_line= 0;
my $tempID = "";
my $tempASIL= "";
my $HighestSRS3ASIL = "NOK";

#below same as for component design 
foreach $one_path (@array2)
{	
		if($one_path =~ /^.*\/List_of_RM_Doc_(\d*)\/ID_(\d*).txt/) # Recognize pattern in file path: .../RM_Doc_XXXXX/ID_YYYYY.txt
		{
      # Open file
      open(FILE, "<", $one_path) or die("Can't open file");
      @lines = <FILE>;
      close(FILE);
		foreach $one_line (@lines)    # Read file line by line
		{
			if($one_line =~ /^Shared Category:\s(.*)/)      {$SRS3category = $1;} #print "$category\n";}
			if($one_line =~ /^Category:\s(.*)/)             {$SRS3category = $1;} #print "$category\n";}
			if($one_line =~ /^ASIL:\s(.*)/)                 {$SRS3asil = $1;} #print "$asil\n";}
			if($one_line =~ /^Document ID:\s(.*)/)          {$SRS3ID = $1;} #print "$ID\n";}
			if($one_line =~ /^Live Item ID:\s(.*)/)         {$SRS3RM_Doc_ID = $1;} #print "$RM_Doc_ID\n";}
			if($one_line =~ /^Document Name:\s(.*)\:(.*)\n$/) 
			{	
				$SRS3shorthandcomponent = $1;
				$SRS3component = $2;
				print "Comp: ".$SRS3component."\n";
				print "Shorthand: ".$SRS3shorthandcomponent."\n";
				if ($SRS3component eq "" or $SRS3component eq " "or $SRS3component eq "\n"or $SRS3component eq "	"){
				$SRS3component = $SRS3shorthandcomponent;	#if the document name is blank or missing a name just use the shorthand
				}
			} 
		}
		if($SRS3category eq "Software Requirement")
		{
			$SW_Req_counter++;
			if($SRS3asil eq "QM")										 {$SRS3asil = "NOK";}
			if($SRS3asil eq "")                                          {$SRS3asil = "NOK";}
			if($SRS3asil eq " ")                                         {$SRS3asil = "NOK";}
			if($SRS3asil eq "\n")                                        {$SRS3asil = "NOK";}
			if($SRS3asil eq "To be determined")                          {$SRS3asil = "NOK";}
			if($SRS3asil eq "Safety relevant - ASIL/SIL not determined") {$SRS3asil = "NOK";}
			if($SRS3asil eq "ASIL A")                                    {$SRS3asil = "A ";}
			if($SRS3asil eq "ASIL B")                                    {$SRS3asil = "B ";}
			if($SRS3asil eq "ASIL B (D)")                                {$SRS3asil = "B ";}
			if($SRS3asil eq "ASIL C")                                    {$SRS3asil = "C ";}
			if($SRS3asil eq "ASIL D")                                    {$SRS3asil = "D ";}
			
			if ($SRS3ID ne $tempID){			#New RMID means push a full new set of information
				$HighestSRS3ASIL = "NOK";
				if ($HighestSRS3ASIL eq "NOK" and $SRS3asil ne "NOK")									{$HighestSRS3ASIL = $SRS3asil;}
				if ($HighestSRS3ASIL  eq "A " and $SRS3asil eq "B " or $SRS3asil eq "C " or $SRS3asil eq "D ")	{$HighestSRS3ASIL = $SRS3asil;} #????parentheses in statement order of operations??
				if ($HighestSRS3ASIL eq "B " and $SRS3asil eq "C " or $SRS3asil eq "D ")					{$HighestSRS3ASIL = $SRS3asil;}
				if ($HighestSRS3ASIL eq "C " and $SRS3asil eq "D " )					   				{$HighestSRS3ASIL = $SRS3asil;}
			
				
				push(@SRS3DocInfoArray, [$SRS3component, $SRS3ID]);
				push @ASILarray,$HighestSRS3ASIL;
				#reset temp variables
				$tempID = $SRS3ID;
				$tempASIL= $SRS3asil;
			}
			if ($SRS3asil ne $tempASIL){		#Same RMID as previous just needs to pop the asil level and push a new asil level
		
				if ($HighestSRS3ASIL eq "NOK" and $SRS3asil ne "NOK")												{$HighestSRS3ASIL = $SRS3asil;}
				if ($HighestSRS3ASIL  eq "A " and $SRS3asil eq "B " or $SRS3asil eq "C " or $SRS3asil eq "D " )		{$HighestSRS3ASIL = $SRS3asil;}
				if ($HighestSRS3ASIL eq "B " and $SRS3asil eq "C " or $SRS3asil eq "D ")							{$HighestSRS3ASIL = $SRS3asil;}
				if ($HighestSRS3ASIL eq "C " and $SRS3asil eq "D " )					   							{$HighestSRS3ASIL = $SRS3asil;}
				
				
				$pop = pop @ASILarray;
				push @ASILarray, $HighestSRS3ASIL;
				$tempID = $SRS3ID;
				$tempASIL= $SRS3asil;
			}
			$SRS3component= ""; 
			$SRS3asil = ""; 
			$SRS3RM_Doc_ID = "";
			$SRS3ID = "";
		}	
	}
}
ExcelWrite(\@DocInfoArray, \@SRS3DocInfoArray, \@ASILarray, \@CompASILarray);		#pass both arrays byref
print "Script finished\n";
$end_run = time();
$run_time = $end_run - $start_run;
$converted_time = sprintf "%02d:%02d:%02d:%02d", (gmtime($run_time))[7,2,1,0];
print "Runtime: ".$run_time." s = ".$converted_time."\n";

