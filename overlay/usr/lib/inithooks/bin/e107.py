#!/usr/bin/python3
"""Set e107 admin password and email

Option:
    --pass=     unless provided, will ask interactively
    --email=    unless provided, will ask interactively

"""

import sys
import getopt
import subprocess
import time
from mysqlconf import MySQL

from libinithooks import inithooks_cache
from libinithooks.dialog_wrapper import Dialog

def usage(s=None):
    if s:
        print("Error:", s, file=sys.stderr)
    print("Syntax: %s [options]" % sys.argv[0], file=sys.stderr)
    print(__doc__, file=sys.stderr)
    sys.exit(1)

def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h",
                                       ['help', 'pass=', 'email='])
    except getopt.GetoptError as e:
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

    password_hash = subprocess.run(
        ["/usr/bin/php", "-r",
         "echo password_hash(stream_get_contents(STDIN), PASSWORD_DEFAULT);"],
        input=password,
        text=True,
        stdout=subprocess.PIPE,
        check=True,
    ).stdout
    if not password_hash.startswith("$2y$"):
        raise RuntimeError("e107 password hashing failed")
    timestamp = int(time.time())

    m = MySQL()
    m.execute('UPDATE e107.e107_user SET user_password=%s WHERE user_loginname=\"admin\";', (password_hash,))
    m.execute('UPDATE e107.e107_user SET user_email=%s WHERE user_loginname=\"admin\";', (email,))
    m.execute('UPDATE e107.e107_user SET user_pwchange=%s WHERE user_loginname=\"admin\";', (timestamp,))

if __name__ == "__main__":
    main()
