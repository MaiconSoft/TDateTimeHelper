{***************************************************************************}
{                                                                           }
{           LayoutDateTime                                                  }
{                                                                           }
{           Copyright (C) MaiconSoft                                     }
{                                                                           }
{           https://github.com/MaiconSoft                                       }
{                                                                           }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Licensed under the Apache License, Version 2.0 (the "License");          }
{  you may not use this file except in compliance with the License.         }
{  You may obtain a copy of the License at                                  }
{                                                                           }
{      http://www.apache.org/licenses/LICENSE-2.0                           }
{                                                                           }
{  Unless required by applicable law or agreed to in writing, software      }
{  distributed under the License is distributed on an "AS IS" BASIS,        }
{  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. }
{  See the License for the specific language governing permissions and      }
{  limitations under the License.                                           }
{                                                                           }
{***************************************************************************}

{
  Parse and format functions uses a string layout to interpret the date and
  time in another string. Theses function are the partial translation of
  Go lang's format.go [https://golang.org/src/time/format.go] (time package)
  code. All features related to time zone have been removed.

  Layout codes supported:

  Date:               | Code:
    month             |   '1'(no leading) or '01' (zero leading)
    month             |   'Jan' (short month name) or 'January' (long month name)
    month             |   '_1' (space leading))
    day               |   '2'(no leading) or '02' (zero leading)
    day               |   '_2' (space leading)
    week day          |   'Mon' (short week day name) or 'Monday' (long week day name)
    year              |   '06' (two digit year) or '2006' (four digit year)
  Time:
    hour              |   '3'(no leading) or '03' (zero leading)
    hour              |   '15'(24 hours mode)
    hour              |   'PM'("AM/PM" mode upercase) or 'pm' ("am/pm" mode lowercase)
    minute            |   '4'(no leading) or '04' (zero leading)
    secound           |   '5'(no leading) or '05' (zero leading)
    milisecound       |   '.999'(no leading) or '.000' (zero leading)
   Symbol
    Finish search     |   '...' (ignore all chars of "value" after this)
   Spaces:
    Will be ignored
   Others:
    Any other word or symbol in layout, must match with "value" string

   "alocal" string define a local code for ICU, this will reflect in months and
    week days names. If not defined (or empty string) the default local will be
    used. For force USA pattern use "alocal = 'en-US'" and for UK, "en-GB"

    ps.: Do not localize code words in layout and not change cases, like
         'January','Monday' etc.
}

unit LayoutDateTime;

interface

uses
  System.SysUtils, System.DateUtils;

type
  TLayoutDateTimeToken = (stdNone, // none
    stdAny, // ...
    stdLongMonth, // "January"
    stdMonth, // "Jan"
    stdNumMonth, // "1"
    stdZeroMonth, // "01"
    stdLongWeekDay, // "Monday"
    stdWeekDay, // "Mon"
    stdDay, // "2"
    stdUnderDay, // "_2"
    stdZeroDay, // "02"
    stdHour, // "15"
    stdHour12, // "3"
    stdZeroHour12, // "03"
    stdMinute, // "4"
    stdZeroMinute, // "04"
    stdSecond, // "5"
    stdZeroSecond, // "05"
    stdLongYear, // "2006"
    stdYear, // "06"
    stdPM, // "PM"
    stdpm_, // "pm"
    stdFracSecond0, // ".000", trailing zeros included
    stdFracSecond9 // ".999",  trailing zeros omitted
);

  TLayoutDateTime = record
  private
    class function GetNum(var value: string; Len: Integer; fixed: boolean =
      False): Integer; static;
    class function Lookup(var value: string; tab: array of string): Integer; static;
    class function NextStdChunk(layout: string; var prefix, suffix: string):
      TLayoutDateTimeToken; static;
    class function Skip(var value: string; prefix: string): boolean; static;
    class procedure Split(input: string; index, len: integer; var prefix, suffix:
      string); static;
  public
    class function Parse(layout, value: string; const alocal: string = ''):
      TDateTime; static;
    class function Format(layout: string; const DateTime: TDateTime; const
      alocal: string = ''): string; static;
  end;

const
  std0x: array[0..5] of TLayoutDateTimeToken = (stdZeroMonth, stdZeroDay,
    stdZeroHour12, stdZeroMinute, stdZeroSecond, stdYear);

implementation

class procedure TLayoutDateTime.Split(input: string; index, len: integer; var
  prefix, suffix: string);
begin
  prefix := input.Substring(0, index);
  suffix := input.Substring(index + len);
end;

class function TLayoutDateTime.NextStdChunk(layout: string; var prefix, suffix:
  string): TLayoutDateTimeToken;
var
  i: integer;
  c: char;
  j: Integer;

  function Check(code: string; std: TLayoutDateTimeToken; var return:
    TLayoutDateTimeToken): boolean;
  begin
    if layout.IndexOf(code) = i then
    begin
      Split(layout, i, code.Length, prefix, suffix);
      return := std;
      exit(true);
    end;
    Result := false;
  end;

begin
  prefix := '';
  suffix := '';
  for i := 0 to layout.Length - 1 do
  begin
    c := layout[i + 1];
    case c of
      'J':
        begin
          if Check('January', stdLongMonth, result) then
            exit;

          if Check('Jan', stdMonth, result) then
            exit;
        end;
      'M':
        begin
          if Check('Monday', stdLongWeekDay, result) then
            exit;
          if Check('Mon', stdWeekDay, result) then
            exit;
        end;

      '0':
        begin
          for j := 1 to 6 do
            if Check('0' + j.ToString, std0x[j - 1], result) then
              exit;

        end;
      '1':
        begin
          if Check('15', stdHour, result) then
            exit;
          if Check('1', stdNumMonth, result) then
            exit;
        end;
      '2':
        begin
          if Check('2006', stdLongYear, result) then
            exit;
          if Check('2', stdDay, result) then
            exit;
        end;

      '_':
        begin
          if Check('_2006', stdLongYear, result) then
            exit;
          if Check('_2', stdUnderDay, result) then
            exit;
        end;

      '3':
        exit(stdHour12);
      '4':
        exit(stdMinute);
      '5':
        exit(stdSecond);
      'P':
        begin
          if Check('PM', stdPM, result) then
            exit;
        end;

      'p':
        begin
          if Check('pm', stdpm_, result) then
            exit;
        end;

      '.':
        begin
          if Check('...', stdAny, result) then
            exit;

          if Check('.999', stdFracSecond9, result) then
            exit;

          if Check('.000', stdFracSecond0, result) then
            exit;
        end;
    else
      begin
        prefix := layout;
        suffix := '';
        Result := stdNone;
      end;
    end;
  end;
end;

class function TLayoutDateTime.Skip(var value: string; prefix: string): boolean;
begin
  Result := false;
  prefix := prefix.Trim;
  value := value.Trim;
  if not prefix.IsEmpty then
  begin
    Result := value.IndexOf(prefix) <> 0;
    if not Result then
      Delete(value, 1, prefix.Length);
  end;
end;

class function TLayoutDateTime.Lookup(var value: string; tab: array of string): Integer;
var
  j: Integer;
  val: string;
begin
  value := value.Trim;
  Result := -1;
  for j := low(tab) to high(tab) do
  begin
    val := tab[j].ToLower;
    if value.ToLower.IndexOf(val) = 0 then
    begin
      Result := j;
      delete(value, 1, val.Length);
      break;
    end;
  end;
end;

class function TLayoutDateTime.GetNum(var value: string; Len: Integer; fixed:
  boolean = false): Integer;
var
  val: string;
begin
  value := value.Trim;
  if value.Length < Len then
    exit(-1); // not length enough

  while Len > 0 do
  begin
    val := value.Substring(0, Len);
    if TryStrToInt(val, Result) then
    begin
      delete(value, 1, Len);
      exit;
    end;

    if fixed then  // then number must have length = len
      exit(-1);

    dec(Len); // try number with less digits
  end;
end;

class function TLayoutDateTime.Parse(layout, value: string; const alocal: string
  = ''): TDateTime;
var
  prefix, sufflix, p: string;
  fs: TFormatSettings;
  pmSet: boolean;
  year, month, day, hour, min, sec, ms: Integer;
begin
  if alocal.Trim.IsEmpty then
    fs := TFormatSettings.Create(SysLocale.DefaultLCID)
  else
    fs := TFormatSettings.Create(alocal);

  pmSet := false;
  year := 1970;
  month := 1;
  day := 1;
  hour := 0;
  min := 0;
  sec := 0;
  ms := 0;

  repeat
    var std := NextStdChunk(layout, prefix, sufflix);
    var stdstr := layout.Substring(prefix.Length, layout.Length - sufflix.Length);

    if Skip(value, prefix) then
      raise Exception.Create('Error: Expected prefix: "' + prefix +
        '", but not found in: ' + value.QuotedString);
    if std = stdAny then
      Break;

    if std = stdNone then
    begin
      if value.Length <> 0 then
        raise Exception.Create('Error: Unknowing pattern in layout');
      Break;
    end;

    layout := sufflix;

    case std of
      stdYear:
        begin
          year := GetNum(value, 2, True);
          if year = -1 then
            raise Exception.Create('Error: Year ' + value.QuotedString +
              'is not a number valid');

          if year >= 69 then
            inc(year, 1900)
          else
            inc(year, 2000);
        end;

      stdLongYear:
        begin
          year := GetNum(value, 4, True);
          if year = -1 then
            raise Exception.Create('Error: Year ' + value.QuotedString +
              'is not a number valid');
        end;
      stdMonth:
        begin
          month := Lookup(value, fs.ShortMonthNames);
          if (month < 0) or (month > 11) then
            raise Exception.Create('Error: Month ' + value.QuotedString +
              ' is not valid');
          inc(month);
        end;
      stdLongMonth:
        begin
          month := Lookup(value, fs.LongMonthNames);
          if (month < 0) or (month > 11) then
            raise Exception.Create('Error: Month ' + value.QuotedString +
              ' is not valid');
          inc(month);
        end;

      stdNumMonth, stdZeroMonth:
        begin
          month := GetNum(value, 2, std = stdZeroMonth);
          if (month < 1) or (month > 12) then
            raise Exception.Create('Error: Month ' + month.ToString +
              ' must be in 1..12');
        end;

      stdWeekDay:
        begin
          Lookup(value, fs.ShortDayNames);
        end;

      stdLongWeekDay:
        begin
          Lookup(value, fs.LongDayNames);
        end;

      stdDay, stdUnderDay, stdZeroDay:
        begin
          day := GetNum(value, 2, (std = stdZeroDay));
          if (day = -1) or (day > 31) then
            raise Exception.Create('Error: Day ' + value.QuotedString + ' is not valid');
        end;

      stdHour:
        begin
          hour := GetNum(value, 2, false);
          if (hour < 0) or (hour > 24) then
            raise Exception.Create('Error: Hour ' + value.QuotedString + ' is not valid');
        end;

      stdHour12, stdZeroHour12:
        begin
          hour := getnum(value, 2, std = stdZeroHour12);
          if (hour < 0) or (hour > 12) then
            raise Exception.Create('Error: Hour ' + value.QuotedString + ' is not valid');
        end;

      stdMinute, stdZeroMinute:
        begin
          min := getnum(value, 2, std = stdZeroMinute);
          if (min < 0) or (min > 60) then
            raise Exception.Create('Error: Minute ' + value.QuotedString +
              ' is not valid');
        end;

      stdSecond, stdZeroSecond:
        begin
          sec := getnum(value, 2, std = stdZeroMinute);
          if (sec < 0) or (sec > 60) then
            raise Exception.Create('Error: Second ' + value.QuotedString +
              ' is not valid');
        end;

      stdPM:
        begin
          p := value.Substring(0, 2);
          if p = 'PM' then
            pmSet := true
          else if p = 'AM' then
            pmSet := false
          else
            raise Exception.Create('Error: PM/AM not valid');
          Delete(value, 1, 2);
        end;

      stdpm_:
        begin
          p := value.Substring(0, 2);
          if p = 'pm' then
            pmSet := true
          else if p = 'am' then
            pmSet := false
          else
            raise Exception.Create('Error: pm/am not valid');
          Delete(value, 1, 2);
        end;

      stdFracSecond9, stdFracSecond0:
        begin
          delete(value, 1, 1);
          ms := GetNum(value, 3, std = stdFracSecond0);
          if (ms < 0) or (ms > 999) then
            raise Exception.Create('Error: Milisecond ' + value.QuotedString +
              ' is not valid');
        end;
    end;
  until (False);

  if (hour < 12) and (pmSet) then
    inc(hour, 12);

  Result := EncodeDateTime(year, month, day, hour, min, sec, ms);
end;

class function TLayoutDateTime.Format(layout: string; const DateTime: TDateTime;
  const alocal: string = ''): string;
const
  PAD_CHAR: array[boolean] of char = (' ', '0');
var
  prefix, sufflix, day_str: string;
  fs: TFormatSettings;
  year, month, day, hour, min, sec, ms, weekday, hour_12: word;
begin
  Result := '';

  if alocal.Trim.IsEmpty then
    fs := TFormatSettings.Create(SysLocale.DefaultLCID)
  else
    fs := TFormatSettings.Create(alocal);

  DecodeDateTime(DateTime, year, month, day, hour, min, sec, ms);
  weekday := DayOfWeek(DateTime);

  repeat
    var std := NextStdChunk(layout, prefix, sufflix);
    var stdstr := layout.Substring(prefix.Length, layout.Length - sufflix.Length);

    if not prefix.IsEmpty then
      Result := Result + prefix;

    if std = stdNone then
      Break;

    layout := sufflix;

    case std of
      stdYear:
        Result := Result + (year mod 100).ToString;

      stdLongYear:
        Result := Result + year.ToString;

      stdMonth:
        Result := Result + fs.ShortMonthNames[month];

      stdLongMonth:
        Result := Result + fs.LongMonthNames[month];

      stdNumMonth, stdZeroMonth:
        Result := Result + month.ToString.PadLeft(2, '0');

      stdWeekDay:
        Result := Result + fs.ShortDayNames[weekday];

      stdLongWeekDay:
        Result := Result + fs.LongDayNames[weekday];

      stdDay, stdUnderDay, stdZeroDay:
        begin
          day_str := day.ToString;
          if std <> stdDay then
            day_str := day_str.PadLeft(2, PAD_CHAR[std = stdZeroDay]);
          Result := Result + day_str;
        end;

      stdHour:
        Result := Result + hour.ToString.PadLeft(2, '0');

      stdHour12, stdZeroHour12:
        begin
          hour_12 := hour mod 12;
          if hour_12 = 0 then
            hour_12 := 12;

          Result := Result + hour_12.ToString.PadLeft(2, '0');
        end;

      stdMinute:
        Result := Result + min.ToString;

      stdZeroMinute:
        Result := Result + min.ToString.PadLeft(2, '0');

      stdSecond:
        Result := Result + sec.ToString;

      stdZeroSecond:
        Result := Result + sec.ToString.PadLeft(2, '0');

      stdPM, stdpm_:
        begin
          var pm: string;
          if hour < 12 then
            pm := fs.TimeAMString
          else
            pm := fs.TimePMString;

          if std = stdPM then
            Result := Result + pm.ToUpper
          else
            Result := Result + pm.ToLower;
        end;

      stdFracSecond9:
        begin
          if ms > 0 then
            Result := Result + '.' + ms.ToString;
        end;

      stdFracSecond0:
        Result := Result + '.' + ms.ToString.PadLeft(3, '0');
    end;
  until (False);
end;

end.

