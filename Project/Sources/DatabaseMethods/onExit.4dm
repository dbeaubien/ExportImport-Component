// Throw-away: ticket 21, part 1 step 5, checks that On Exit runs when Switch to target calls CREATE DATA FILE, then deletes this method.
File(Data file; fk platform path).parent.file("On Exit ran.txt").setText(Timestamp+" "+Data file)
