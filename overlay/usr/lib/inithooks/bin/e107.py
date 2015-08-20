#!/usr/bin/python
"""Set e107 admin password and email

Option:
    --pass=     unless provided, will ask interactively
    --email=    unless provided, will ask interactively

"""

import sys
import getopt
import inithooks_cache
import hashlib
from datetime import datetime
from time import mktime

from dialog_wrapper import Dialog
from mysqlconf import MySQL

def usage(s=None):
    if s:
        print >> sys.stderr, "Error:", s
    print >> sys.stderr, "Syntax: %s [options]" % sys.argv[0]
    print >> sys.stderr, __doc__
    sys.exit(1)

def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h",
                                       ['help', 'pass=', 'email='])
    except getopt.GetoptError, e:
        usage(e)

    password = ""
    email = ""
    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()
        elif opt == '--pass':
            password = val
        elif opt == '--email':
            email = val

    if not password:
        d = Dialog('TurnKey Linux - First boot configuration')
        password = d.get_password(
            "e107 Password",
            "Enter new password for the e107 'admin' account.")

    if not email:
        if 'd' not in locals():
            d = Dialog('TurnKey Linux - First boot configuration')

        email = d.get_email(
            "e107 Email",
            "Enter email address for the e107 'admin' account.",
            "admin@example.com")

    inithooks_cache.write('APP_EMAIL', email)

    hash = hashlib.md5(password).hexdigest()
    timestamp = int(mktime(datetime.now().timetuple()))

    m = MySQL()
    m.execute('UPDATE e107.e107_user SET user_password=\"%s\" WHERE user_loginname=\"admin\";' % hash)
    m.execute('UPDATE e107.e107_user SET user_email=\"%s\" WHERE user_loginname=\"admin\";' % email)
    m.execute('UPDATE e107.e107_user SET user_pwchange=\"%s\" WHERE user_loginname=\"admin\";' % timestamp)

if __name__ == "__main__":
    main()

