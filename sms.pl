#!/usr/bin/perl
#
#SMS:xknapo02
#---------------------------------------------------------------------------
#SMS COMPRESS - projekt 1 pro predmet IPP 2010/2011
#Autor: Martin Knapovsky Email: xknapo02@stud.fit.vutbr.cz
#Popis: Program zpracovava vstupni text podle zadanych parametru viz. --help
#Datum: 4.4.2011
#
#------------------VYHRAZENO-PRO-DOPLNUJICI-INFORMACE-----------------------
#
#---------------------------------------------------------------------------
#-------------------------ZACATEK-PROGRAMU----------------------------------
#---------------------------------------------------------------------------

use strict;
use utf8;
#use warnings;
use locale;
use IO::File;
use encoding 'utf8';

#globalni promenne
our %result;
#defaultne se pouzivaji STDIN a STDOUT
our %files = ( "--input" => '-', "--output" => '-', );
our @words;
our @characters;
our $input;
our $processed;
our $xml_dict;
our @expansive_rules;
our @expansive_cs_rules;
our @compact_rules;
our @compact_cs_rules;

#Napoveda-------------------------------------------------------------------
sub print_help {
    print "SMS Compress\n";
    print "Parametry: \n";
    print "[--input=%] - vstupni soubor\n";
    print "[--output=%] - vystupni soubor\n";
    print "[--dict=%] - soubor obsahujici XML slovnik\n";
    print "[-r] - odstraneni ceske diakritiky\n";
    print "[-c] - provede kompresi SMS na camel notaci\n";
    print "[-a] - na camel notaci prevadi pouze slova ze samych malych pismen\n";
    print "     - vyzadovana kombinace s [-c]\n";
    print "[-b] - vynecha z komprese slova napsana velkymi pismeny\n";
    print "     - vyzadovana kombinace s [-c], nepovoleno kombinovat s [-a]\n";
    print "[-v] - provede aplikaci pravidel ze slovniku zkratek\n";
    print "     - vyzadovan soubor se zkratkami zadany pres [--dict=%]\n";
    print "[-e] - aplikuje pouze expanzivni pravidla ze zadaneho slovniku\n";
    print "     - vyzaduje parametr [-v], nelze kombinovat s [-s]\n";
    print "[-s] - aplikuje pouze zkracujici pravidla ze zadaneho slovniku zkratek\n";
    print "     - vyzaduje parametr [-v], nelze kombinovat s [-e]\n";
    print "[-n] - vypise minimalni pocet SMS, na ktere je nutno vystupni SMS rozdelit\n";   
}

#Tiskne chybove hlasky podle parametru---------------------------------------
sub print_error {
    my $errtype = shift;
    if($errtype =~ m{^ARGV$}) {print "Chyba: Spatny format parametru skriptu, nebo byla pouzita zakazana kombinace parametru.\n"; exit(1); }
    if($errtype =~ m{^FILE$}) {print "Chyba: Neexistujici zadany vstupni soubor, nebo chyba otevreni zadaneho vstupniho souboru."; exit(2); }
    if($errtype =~ m{^OUT$}) {print "Chyba: Chyba pri pokusu o otevreni zadaneho vystupniho souboru pro zapis.\n"; exit(3); }
    if($errtype =~ m{^XML$}) {print "Chyba: Chybny format vstupniho souboru XML.\n"; exit(4); }
}

#Nacte parametry ze vstupu a urci tak funkci programu------------------------
sub parse_argv {
    our %result;
    our %files;
    #inicializace hashovaciho pole
    %result = ( "error" => '0' , "help" => '0' , "--input" => '0' , "--output" => '0',
                "--dict" => '0' , "-r" => '0' , "-c" => '0' , "-a" => '0' , "-b" => '0' ,
                "-v" => '0' , "-e" => '0' , "-s" => '0' , "-n" => '0' );
    
    #pokud nejsou zadany parametry
    if( (my $argument_count = @_) == 0 ) { $result{"error"} = 1; }
    
    #nacitani parametru
    while(my $argument = shift){
        if($argument =~ m{^--help$}) { $result{"--help"} = 1; }
        elsif($argument =~ m{^--input=(.*)$}) { $files{"--input"} = $1; $result{"--input"} += 1; }
        elsif($argument =~ m{^--output=(.*)$}) { $files{"--output"} = $1; $result{"--output"} += 1;}
        elsif($argument =~ m{^--dict=(.*)$}) { $files{"--dict"} = $1; $result{"--dict"} += 1; }
        elsif($argument =~ m{^-r$}) { $result{"-r"} += 1; }
        elsif($argument =~ m{^-c$}) { $result{"-c"} += 1; }
        elsif($argument =~ m{^-a$}) { $result{"-a"} += 1; }
        elsif($argument =~ m{^-b$}) { $result{"-b"} += 1; }
        elsif($argument =~ m{^-v$}) { $result{"-v"} += 1; }
        elsif($argument =~ m{^-e$}) { $result{"-e"} += 1; }
        elsif($argument =~ m{^-s$}) { $result{"-s"} += 1; }
        elsif($argument =~ m{^-n$}) { $result{"-n"} += 1; }
        else { $result{"error"} = 1; }
    }
    
    #kontrola kombinaci parametru
    if( $result{"-a"} == 1 && $result{"-c"} != 1 ) { $result{"error"} = 1; }
    elsif( $result{"-b"} == 1 && $result{"-a"} == 1 ) { $result{"error"} = 1; }
    elsif( $result{"-b"} == 1 && $result{"-c"} != 1 ) { $result{"error"} = 1; }
    elsif( $result{"--dict"} != undef && $result{"-v"} != 1 ) { $result{"error"} = 1; }
    elsif( $result{"--dict"} == undef && $result{"-v"} == 1 ) { $result{"error"} = 1; }
    elsif( ($result{"-e"} == 1 && $result{"-v"} != 1) || ($result{"-e"} == 1 && $result{"-s"} == 1)) { $result{"error"} = 1; }
    elsif( ($result{"-s"} == 1 && $result{"-v"} != 1) || ($result{"-s"} == 1 && $result{"-e"} == 1)) { $result{"error"} = 1; }
    
    #kontrola, zda je parametr zadan pouze jednou
    foreach my $key (keys %result) {
        if( $result{$key} > 1) { $result{"error"} = 1; }
    }
}

#odstrani diakritiku---------------------------------------------------------
sub remove_dia {
		my $string_orig = shift;
    my $string = $string_orig;
    #nahrazeni znaku
    $string =~ tr/ĚŠČŘŽĎŤŇÁÉÍÓÚŮÝěščřžďťňáéíóúůý/ESCRZDTNAEIOUUYescrzdtnaeiouuy/;
    $processed = $string;
    #pokud se neco prevedlo, vraci se hodnota 1
    if($processed ne $string_orig) { return 1;}
}

#----------------------------------------------------------------------------
#prevod na camel notaci, ktery je pouzivan pri zadani parametru -b nebo -a
#nemaze globalni pole $processed, pouze do nej pridava znaky
sub convert_to_camel {
		my $line = lc shift;
		my @chars = split "", $line;
		my $inside_word = 0;
		foreach my $char (@chars) {
          #znakem je pismeno
			    if(  $char =~ m{[[:alpha:]]}){
			      if($inside_word == 0){
              #prevedu na velke pismeno a ulozim do glob. pole
				      $char = uc $char;
					    $inside_word = 1;
              $processed = $processed . $char;
            }
				    else{
              $processed = $processed . $char;
						}
			    } 
          #nacteny znak je bilym znakem - preskakuji ho
			    elsif($char =~ m{[[:space:]]}){
				    $inside_word = 0;
			    }
          #jiny znak
			    else{
            $inside_word = 0;
            $processed = $processed . $char;
			    }
		}
}

#prevod na camel notaci------------------------------------------------------
#funguje stejne jako convert_to_camel(), avsak tato verze prepisuje gl. prom $processed
sub convert_to_camel_simple {
		my $line = lc shift;
		my @chars = split "", $line;
		my $inside_word = 0;
    $processed = '';
		foreach my $char (@chars) {
			    if(  $char =~ m{[[:alpha:]]}){
			      if($inside_word == 0){
				      $char = uc $char;
					    $inside_word = 1;
              $processed = $processed . $char;
            }
				    else{
              $processed = $processed . $char;
						}
			    } 
          #nacteny znak je bilym znakem - preskakuji ho
			    elsif($char =~ m{[[:space:]]}){
				    $inside_word = 0;
			    }
          #jiny znak
			    else{
            $inside_word = 0;
            $processed = $processed . $char;
			    }
		}
}

#zjisti, zda jsou vsechna pismena mala---------------------------------------
sub is_lower {
  my $is_lower = 1;
  my @char = split "", shift;
  foreach my $char (@char) {
    if(!($char =~ m{[[:lower:]]})) { $is_lower = 0; }
  }
  return $is_lower;
}

#prevadi na camel notaci pouze slova, slozena z malych pismen----------------
sub convert_lc_to_camel {
  my @chars = split "", shift;
  my $buffer = '';
  my $inside_word = 1;
  $processed = '';
  foreach my $char (@chars) {
    #pokud mame pismeno, pridame ho do bufferu
    if( $char =~ m{[[:alpha:]]}) { $buffer .= $char; }
    #mezera - prevadime $buffer na camel notaci, nebo pridavame do $processed
    elsif( $char =~ m{[[:space:]]}) {
      if( is_lower( $buffer ) ) { convert_to_camel( $buffer ); }
      else { $processed .= $buffer; }
      $buffer = '';
    }
    #opet prevod, nebo pridani do $processed podle toho, zda jsou v bufferu mala pismena, ci ne
    else {
      if ( is_lower( $buffer )) { convert_to_camel( $buffer ); }
      else { $processed .= $buffer; }
      $buffer = '';
      $processed .= $char;
    }
  }
}

#zjisti, zda jsou vsechna pismena velka--------------------------------------
sub is_upper {
  my $is_upper = 1;
  my @char = split "", shift;
  foreach my $char (@char) {
    if(!($char =~ m{[[:upper:]]})) { $is_upper = 0; }
  }
  return $is_upper;
}

#neprevadi na camel notaci slova napsana velkymi pismeny---------------------
#funkce je obdobna jako u convert_lc_to_camel, avsak zde
#testujeme $buffer na velka pismena pomoci is_upper()
sub convert_no_uc_to_camel {
  my $is_upper = 0;
  my $buffer = '';
  my $inside_word = 1;
  my @chars = split "", shift;
  $processed = '';
  foreach my $char (@chars) {
    if( $char =~ m{[[:alpha:]]}) { $buffer .= $char; }
    elsif( $char =~ m{[[:space:]]}) { 
      if( is_upper( $buffer ) ) { $processed .= $buffer; } 
      else { convert_to_camel( $buffer ); }
      $buffer = '';
    }
    else { 
      if ( is_upper( $buffer )) { $processed .= $buffer; }
      else { convert_to_camel( $buffer ) }
      $buffer = '';
      $processed .= $char;
    }
  }
}

#rozvine zkratky-------------------------------------------------------------
#komentare pouze tady...ostatni funkce opet obdobne
sub expand_by_xml_rules {
  my $string = shift;
  my $offset = 0;
  #pro kazde expanzivni pravidlo, ktere neni case sensitive
  foreach my $substring_hash (@expansive_rules){
    #hledame podretez zadaneho retezce a aplikujeme pravidla do te doby, dokud se jiz
    #vyhledavany podretez v retezci nevyskytuje
    while( ($offset = index(uc $string, uc $$substring_hash{'abbrev'})) != -1) { 
      substr $string, $offset, length($$substring_hash{'abbrev'}), $$substring_hash{'text'};
    }
  }
  #expandovanym retezem prepiseme globalni promennou $processed
  $processed = $string;
} 

#expanduje podle case-sensitive pravidel ze slovniku XML--------------------
sub expand_by_xml_cs_rules {
  my $string = shift;
  my $offset = 0;
  foreach my $substring_hash (@expansive_cs_rules){
    while( ($offset = index($string, $$substring_hash{'abbrev'})) != -1) { 
      substr $string, $offset, length($$substring_hash{'abbrev'}), $$substring_hash{'text'};
    }
  }
  $processed = $string;
} 

#redukuje podle XML slovniku--------------------------------------------------
sub compact_by_xml_rules {
  my $string = shift;
  my $offset = 0;
  foreach my $substring_hash (@compact_rules){
    while( ($offset = index(uc $string, uc $$substring_hash{'text'})) != -1) { 
      substr $string, $offset, length($$substring_hash{'text'}), $$substring_hash{'abbrev'};
    }
  }
  $processed = $string;
}

#redukuje podle case-sensitive pravidel ze slovniku XML-----------------------
sub compact_by_xml_cs_rules {
  my $string = shift;
  my $offset = 0;
  foreach my $substring_hash (@compact_cs_rules){
    while( ($offset = index($string, $$substring_hash{'text'})) != -1) { 
      substr $string, $offset, length($$substring_hash{'text'}), $$substring_hash{'abbrev'};
    }
  }
  $processed = $string;
}

#-----------------------------------------------------------------------------
#-------------------------TADY-KONCI-SUBRUTINY--------------------------------
#-----------------------------------------------------------------------------
#nacteme parametry prikazoveho radku a zkontrolujeme jejich spravnost---------
parse_argv(@ARGV);
#pri zadani parametru --help vytiskneme napovedu
if( $result{"--help"} == 1 ) { print_help(); exit(0); }
#pri spatne kombinaci parametru, nebo pri spatne zadanych parametrech koncime s chybou
if( $result{"error"} == 1 ) { print_error("ARGV"); }

#otevreni a kontrola souboru pro cteni a zapis--------------------------------
our $fh_input = new IO::File "< $files{'--input'}";
if(!defined $fh_input) { print_error("FILE"); }
our $fh_output = new IO::File "> $files{'--output'}";
if(!defined $fh_output) { print_error("OUT"); }

#vstupni soubor je kodovan v UTF8---------------------------------------------
binmode($fh_input, ':utf8');
binmode($fh_output, ':utf8');

#otevreni slovniku a XML Parser-----------------------------------------------
if( $result{'--dict'} == 1 ) {
  #otevreni XML souboru a prepnuti na UTF8 kodovani
  our $fh_dict = new IO::File "< $files{'--dict'}";
  binmode($fh_dict, ':utf8');
  my $xml_is_dict = 0;  #znaci, zda je XML korektni
  my $inside_rule = 0;
  my $line_counter = 0;
  
  while( my $xml_test_line = <$fh_dict> ) {
    $line_counter++; #pro ucely debuggovani
    chomp $xml_test_line; #neni zrejme nutne
    #musime najit tento tag, jinak neni XML korektni. Stejne tak musime 
    #najit k tomuto tagu tag parovy
    if( $xml_test_line =~ m{^<sms-abbreviation-dictionary>$} ){
      $xml_is_dict = 1;
        #pokud jsme tag <sms-abbre...> nalezli pokracujeme s parsovanim
        while( my $xml_line = <$fh_dict> ) {
          $line_counter++;
          #nalezen tag <rule> 
          if ( $xml_line =~ m{^[[:space:]]*<rule>[[:space:]]*$} ) { 
            #poznacime si, ze jsme uvnitr pravidla, a ze jsme zatim nenacetli povinne tagy <abbrev> a <text>
            $inside_rule = 1; my $abbrev = 0; my $text = 0;
            #napnime hash, na ktery budeme pozdeji odkazovat pomoci globalniho pole
            my %rule_hash = ( 'casesensitive' => '0', 'abbrev' => '', 'text' => '', );
            #tady nemenit poradi podminek - prioritni vyhodnoceni
            while( ( $inside_rule == 1 ) && ( my $xml_element = <$fh_dict> ) ) {
              $line_counter++;
              #nalezen tag <abbrev> - pridani do hashe a poznaceni informace o jeho nalezeni
              if ( $xml_element =~ m{^[[:space:]]*<abbrev>(.*?)</abbrev>[[:space:]]*$}) { $abbrev = 1; $rule_hash{'abbrev'} = $1; }
              #nalezen tag <text> - opet pridame do hashe a poznacime si informaci o jeho nalezeni
              elsif ( $xml_element =~ m{^[[:space:]]*<text>(.*?)</text>[[:space:]]*$}) { $text = 1;  $rule_hash{'text'} = $1; }
              #nalezen tag </rule> - nastavime, ze jsme ukoncili nacitani pravidla a kontrolujeme jeho spravnost
              elsif ( $xml_element =~ m{^[[:space:]]*</rule>[[:space:]]*$} ) { 
                $inside_rule = 0; 
                #nebyli nacteny povinne tagy <abbrev> a <rule> - XML slovnik je nekorektni
                if( !($abbrev == 1 && $text == 1) ) { $xml_is_dict = 0; }
                #vse v poradku, pridame odkaz na hash do globalniho pole, ktere koresponduje s typem pravidla
                else { push(@compact_rules, \%rule_hash); }
              }
              #nacetli jsme neco jineho nez povolene tagy - XML slovnik je nekorektni
              else {  $xml_is_dict = 0; $inside_rule = 0;  }
            }
          }
          #tady a dale je funkce vyhledavani tagu v pravidlech obdobna jako u samotneho tagu <rule>
          #podle typu pravidla pridavame odkaz na hash s pravidlem do odpovidajiciho globalniho pole
          elsif ( $xml_line =~ m{^[[:space:]]*<rule[[:space:]]+expansive='1'[[:space:]]*>[[:space:]]*$} ) { 
            $inside_rule = 1; my $abbrev = 0; my $text = 0;
            my %rule_hash = ( 'casesensitive' => '0', 'abbrev' => '', 'text' => '' );
            while( ( $inside_rule == 1 ) && ( my $xml_element = <$fh_dict> ) ) {
              $line_counter++;
              if ( $xml_element =~ m{^[[:space:]]*<abbrev>(.*?)</abbrev>[[:space:]]*$} ) { $abbrev = 1; $rule_hash{'abbrev'} = $1;  }
              elsif ( $xml_element =~ m{^[[:space:]]*<text>(.*?)</text>[[:space:]]*$}) { $text = 1;  $rule_hash{'text'} = $1; }
              elsif ( $xml_element =~ m{^[[:space:]]*</rule>[[:space:]]*$} ) { 
                $inside_rule = 0; 
                if ( !($abbrev == 1 && $text == 1) ) { $xml_is_dict = 0; }
                else { push(@expansive_rules, \%rule_hash); }
              }
              else {  $xml_is_dict = 0; $inside_rule = 0;  }
            }
          }
          elsif ( $xml_line =~ m{^[[:space:]]*<rule[[:space:]]+expansive='1'[[:space:]]+casesensitive='1'[[:space:]]*>[[:space:]]*$} ) { 
            $inside_rule = 1; my $abbrev = 0; my $text = 0;
            my %rule_hash = ( 'casesensitive' => '1', 'abbrev' => '', 'text' => '', );
            while( ( $inside_rule == 1 ) && ( my $xml_element = <$fh_dict> ) ) {
              $line_counter++;
              if ( $xml_element =~ m{^[[:space:]]*<abbrev>(.*?)</abbrev>[[:space:]]*$}) { $abbrev = 1; $rule_hash{'abbrev'} = $1; }
              elsif ( $xml_element =~ m{^[[:space:]]*<text>(.*?)</text>[[:space:]]*$}) { $text = 1;  $rule_hash{'text'} = $1; }
              elsif ( $xml_element =~ m{^[[:space:]]*</rule>[[:space:]]*$} ) { 
                $inside_rule = 0; 
                if ( !($abbrev == 1 && $text == 1) ) { $xml_is_dict = 0; }
                else { push(@expansive_cs_rules, \%rule_hash); }
                }
              else {  $xml_is_dict = 0; $inside_rule = 0;  } 
            }
          }
          elsif ( $xml_line =~ m{^[[:space:]]*<rule[[:space:]]+casesensitive='1'[[:space:]]*>[[:space:]]*$} ) { 
            $inside_rule = 1; my $abbrev = 0; my $text = 0;
            my %rule_hash = ( 'casesensitive' => '1', 'abbrev' => '', 'text' => '', );
            while( ( $inside_rule == 1 ) && ( my $xml_element = <$fh_dict> ) ) {
              $line_counter++;
              if ( $xml_element =~ m{^[[:space:]]*<abbrev>(.*?)</abbrev>[[:space:]]*$}) { $abbrev = 1; $rule_hash{'abbrev'} = $1; }
              elsif ( $xml_element =~ m{^[[:space:]]*<text>(.*?)</text>[[:space:]]*$}) { $text = 1;  $rule_hash{'text'} = $1; }
              elsif ( $xml_element =~ m{^[[:space:]]*</rule>[[:space:]]*$} ) { 
                $inside_rule = 0;
                if ( !($abbrev == 1 && $text == 1) ) { $xml_is_dict = 0; }
                else { push(@compact_cs_rules, \%rule_hash); }
              }
              else {  $xml_is_dict = 0; $inside_rule = 0;  }  
            }
          }
          #nacetli jsme neco jineho nez <rule .*>
          else {
            #pokud se nejedna o ukoncujici tag </sms-abbreviation-dictionary>, ktery ocekavame, je XML slovnik nekorektni
            if(!($xml_line =~ m{^[[:space:]]*</sms-abbreviation-dictionary>[[:space:]]*$})) { 
              $xml_is_dict = 0;
            }
          }
        }
    }
  }
  #parsovany slovnik je nekorektni, tiskneme chybu a koncime vypocet
  if( $xml_is_dict == 0 ) { print_error("XML"); } 
}

#nacteni vstupu---------------------------------------------------------------------
while( my $input_line = <$fh_input> ){
  #chomp $input_line;
  $processed .= $input_line;
}


#odstaneni diakritiky---------------------------------------------------------------
if( $result{'-r'} == 1 ) { remove_dia( $processed ); }
#aplikuje pravidla definovana v XML slovniku
if( $result{'-v'} == 1 ) { 
  #aplikuje pouze expanzivni pravidla
  if( $result{'-e'} == 1 ) { 
    expand_by_xml_rules( $processed );
    expand_by_xml_cs_rules( $processed );
  }
  #aplikace zkracujich pravidel
  elsif( $result{'-s'} == 1 ) {
    compact_by_xml_rules( $processed );
    compact_by_xml_cs_rules( $processed );
  }
  #aplikace expanze a pak zkracujicich pravidel
  else{  
    expand_by_xml_rules( $processed );
    expand_by_xml_cs_rules( $processed );
    compact_by_xml_rules( $processed );
    compact_by_xml_cs_rules( $processed );
  }
}

#prevod na camel notaci------------------------------------------------------------
if( $result{'-c'} == 1 ) {
  #prevod slov z malych pismen na camel notaci
  if( $result{'-a'} == 1 ) { convert_lc_to_camel( $processed ); }
  #neprevadi slova psana velkymi pismeny
  elsif( $result{'-b'} == 1 ) { convert_no_uc_to_camel( $processed ); }
  #klasicky prevod na camel notaci
  else{ convert_to_camel_simple( $processed ); }
}

#vypis poctu sms------------------------------------------------------------------
if( $result{'-n'} == 1 ) { 
  my $sms_count = 0;
  my $message_length = length $processed;
  #obsahuje zpracovana zprava interpunkci?
  if(remove_dia( $processed )) { 
    #zprava je delsi jak 70 znaku a je s interpunkci, k vypoctu poctu sms
    #pripoctu 1, jelikoz cislo pak prevadim na int oseknutim desetinne casti
    if( $message_length > 70 ) { $sms_count = ($message_length / 67) + 1; }
    elsif( $message_length > 0 ) { $sms_count = 1; }
  }
  #zprava neobsahuje interpunkci
  else {
    if( $message_length > 160 ) { $sms_count = ($message_length / 153) + 1; }
    elsif( $message_length > 0 ){ $sms_count = 1; }
  }
  print $fh_output int($sms_count);
}
else{
  #vypis zpracovane zpravy
  print $fh_output $processed;
}

#program probehl uspesne---------------------------------------------------------
exit(0);
#--------------------------------------------------------------------------------
#--------------------------------KONEC-PROGRAMU----------------------------------
#--------------------------------------------------------------------------------
