An ArchivesSpace mysqldump obfuscator
=====================================

Let's say you're paranoid and secretive, yet need to share your
ArchivesSpace database with someone to help them troubleshoot an issue
you're seeing.  Don't remove your tinfoil hat just yet, because here's
a tool that can remove all the juicy bits from your database dump
while leaving its basic structure intact!

Supposing that you've run a command like:

     mysqldump -uroot mydatabase > mydatabase.dump

You can scrub that dump file by checking out this repository and then
running:

     cd mysqldump-obfuscator
     ruby main.rb < /path/to/mydatabase.dump > cleaned-up-database.sql

If all goes well, `cleaned-up-database.sql` should now contain a
version of your database with jibberish replacing all of the textual
data.  Review this file to make sure you're happy with the
result--don't take my word for it!

## Usernames and passwords

All usernames will be scrambled, and their passwords will be set back
to 'admin'.

## What information is still shared?

Some bits of the database aren't sanitized.  Namely:

  * Any numbers are still there.  The dump will still give an
    indication of how many records of each type you have.

  * Records are still linked together in their original arrangement.

  * Any dates are unchanged.

  * 4-part identifiers for accessions and resources are unchanged.

  * Container and container profile extents and dimensions are
    unchanged.

  * Collection management processing hours per foot estimates, total
    extents and total hours are unchanged.

These probably could be sensibly sanitized, but didn't seem hugely
sensitive.  Let me know if you're worried about any of these and I'll
see what I can do.
