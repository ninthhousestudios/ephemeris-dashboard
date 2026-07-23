

Calendar polish
some weird things happenings around the turnover. see screenshots

1582-10-07 doesnt exist in Gregorian but we can choose it

leap years:
Set the dropdown to Julian.

Enter date 1900-02-29.

Pass Criteria: 1900-02-29 must be accepted as a valid date and return a valid JD (2415079.5).
-> doesnt. no error but nothing happens. if i switch to gregorian, it goes to the
current date

Switch the dropdown to Gregorian.

Pass Criteria: The date 1900-02-29 should throw a validation error or roll over to 1900-03-01, because Feb 29, 1900 does not exist in the Gregorian calendar!
-> no error, but nothing happens
