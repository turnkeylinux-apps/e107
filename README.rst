e107 - Content Management system
================================

`e107`_ is an Advanced Content Publishing Solution for Website Pages,
Documents, Menus and Links (Content Management System) which gives you a
totally dynamic and professional website "out of the box". It's easily
customized and doesn't require any knowledge of programming languages in
order to use it.

This appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- e107 configurations:
   
   - Installed from upstream source code to /var/www/e107

     **Security note**: Updates to e107 may require supervision so
     they **ARE NOT** configured to install automatically. e107 provide
     upgrade scripts as well as full installers. Please see `e107
     documentation`_

- SSL support out of the box.
- `Adminer`_ administration frontend for MySQL (listening on port
  12322 - uses SSL).
- Postfix MTA (bound to localhost) to allow sending of email (e.g.,
  password recovery).
- Webmin modules for configuring Apache2, PHP, MySQL and Postfix.
- **Gotcha**: When attempting to log in when browsing via IP address,
  you might get an 'Access Denied' error. Use an FQDN instead.

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH, MySQL: username **root**
-  Adminer: username **adminer**
-  e107: username **admin**

.. _e107: https://e107.org/
.. _TurnKey Core: https://www.turnkeylinux.org/core
.. _e107 documentation: https://e107.org/get-started
.. _Adminer: https://www.adminer.org/
