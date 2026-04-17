//%attributes = {"invisible":true,"preemptive":"capable"}
// Method: Date2String ( date {; formatStr} ) : formated date as string
// Method: Date2String ( date {; text} ) : text
//
//   Supported formats: mm, m1, month, mon, dd, d1, day, dayShort, yyyy, yy
//   Defaults to "mm/dd/yyyy".
//   If a date of !00/00/00! is passed then a blank string is returned.
// ===============================================================
// ---- PARAMETERS AND RESULTS ----
//   $1 [in]: date to format
//   $2 [optional in]: format to convert date to
//   $0 [out]: formated date as string
// ---- DESCRIPTION ----
//   This method converts the date into a string as dictated by the
//   optional format string. If the format string is not specified then
//   it defaults to "mm/dd/yyyy".
//
//   If a date of !00/00/00! is passed then a blank string is returned.
//
//   The following is the text that is converted by the format string
//   "mm" is converted to a two digit month
//   "dd" is converted to a two digit day
//   "yyyy" is converted to a four digit year
//   "yy" is converted to a two digit year
//   "month" is converted to the full month name
//   "mon" is converted to an abbreviated month name
//   "day" is converted to the full day name
// ===============================================================
#DECLARE($date_to_convert : Date; $date_format : Text) : Text

// return blank string if date !00/00/00!
If ($date_to_convert=!00-00-00!)
	$date_format:=""
	return $date_format
End if 

If ($date_format="")
	$date_format:="mm/dd/yyyy"
End if 

var $day_of; $month_of; $year_of; $week_day_number : Integer
$day_of:=Day of:C23($date_to_convert)
$month_of:=Month of:C24($date_to_convert)
$year_of:=Year of:C25($date_to_convert)
$week_day_number:=Day number:C114($date_to_convert)

var $day_of_str_one; $day_of_str_two; $month_of_str_one; $month_of_str_two : Text
$day_of_str_one:=String:C10($day_of)
$day_of_str_two:=String:C10($day_of; "00")
$month_of_str_one:=String:C10($month_of; "00")
$month_of_str_two:=String:C10($month_of)

// Put the year in the string
$date_format:=Replace string:C233($date_format; "yyyy"; String:C10($year_of))
$date_format:=Replace string:C233($date_format; "yy"; String:C10(Mod:C98($year_of; 100); "00"))

// Put the Month in the string
$date_format:=Replace string:C233($date_format; "mm"; $month_of_str_one)
$date_format:=Replace string:C233($date_format; "m1"; $month_of_str_two)
Case of 
	: ($month_of=1)
		$date_format:=Replace string:C233($date_format; "Month"; "January")
		$date_format:=Replace string:C233($date_format; "Mon"; "Jan")
	: ($month_of=2)
		$date_format:=Replace string:C233($date_format; "Month"; "February")
		$date_format:=Replace string:C233($date_format; "Mon"; "Feb")
	: ($month_of=3)
		$date_format:=Replace string:C233($date_format; "Month"; "March")
		$date_format:=Replace string:C233($date_format; "Mon"; "Mar")
	: ($month_of=4)
		$date_format:=Replace string:C233($date_format; "Month"; "April")
		$date_format:=Replace string:C233($date_format; "Mon"; "Apr")
	: ($month_of=5)
		$date_format:=Replace string:C233($date_format; "Month"; "May")
		$date_format:=Replace string:C233($date_format; "Mon"; "May")
	: ($month_of=6)
		$date_format:=Replace string:C233($date_format; "Month"; "June")
		$date_format:=Replace string:C233($date_format; "Mon"; "Jun")
	: ($month_of=7)
		$date_format:=Replace string:C233($date_format; "Month"; "July")
		$date_format:=Replace string:C233($date_format; "Mon"; "Jul")
	: ($month_of=8)
		$date_format:=Replace string:C233($date_format; "Month"; "August")
		$date_format:=Replace string:C233($date_format; "Mon"; "Aug")
	: ($month_of=9)
		$date_format:=Replace string:C233($date_format; "Month"; "September")
		$date_format:=Replace string:C233($date_format; "Mon"; "Sep")
	: ($month_of=10)
		$date_format:=Replace string:C233($date_format; "Month"; "October")
		$date_format:=Replace string:C233($date_format; "Mon"; "Oct")
	: ($month_of=11)
		$date_format:=Replace string:C233($date_format; "Month"; "November")
		$date_format:=Replace string:C233($date_format; "Mon"; "Nov")
	: ($month_of=12)
		$date_format:=Replace string:C233($date_format; "Month"; "December")
		$date_format:=Replace string:C233($date_format; "Mon"; "Dec")
End case 

Case of 
	: ($week_day_number=1)
		$date_format:=Replace string:C233($date_format; "dayShort"; "Sun")
		$date_format:=Replace string:C233($date_format; "day"; "Sunday")
	: ($week_day_number=2)
		$date_format:=Replace string:C233($date_format; "dayShort"; "Mon")
		$date_format:=Replace string:C233($date_format; "day"; "Monday")
	: ($week_day_number=3)
		$date_format:=Replace string:C233($date_format; "dayShort"; "Tue")
		$date_format:=Replace string:C233($date_format; "day"; "Tuesday")
	: ($week_day_number=4)
		$date_format:=Replace string:C233($date_format; "dayShort"; "Wed")
		$date_format:=Replace string:C233($date_format; "day"; "Wednesday")
	: ($week_day_number=5)
		$date_format:=Replace string:C233($date_format; "dayShort"; "Thu")
		$date_format:=Replace string:C233($date_format; "day"; "Thursday")
	: ($week_day_number=6)
		$date_format:=Replace string:C233($date_format; "dayShort"; "Fri")
		$date_format:=Replace string:C233($date_format; "day"; "Friday")
	: ($week_day_number=7)
		$date_format:=Replace string:C233($date_format; "dayShort"; "Sat")
		$date_format:=Replace string:C233($date_format; "day"; "Saturday")
End case 

// Put the day in the string
$date_format:=Replace string:C233($date_format; "d1"; $day_of_str_one)
$date_format:=Replace string:C233($date_format; "dd"; $day_of_str_two)

return $date_format
