#!/bin/bash
set -Eeuo pipefail
umask 077

result=${TKL_TEST_RESULT:?TKL_TEST_RESULT is required}
app_password=${TKL_TEST_APP_PASS:?TKL_TEST_APP_PASS is required}
cookie=/tmp/tkl-e107-cookie.$$
page=/tmp/tkl-e107-page.$$

report_error() {
    printf 'test_failure line=%s status=%s command=%q\n' \
        "$1" "$2" "$3" >&2
    exit "$2"
}

cleanup() {
    rm -f -- "$cookie" "$page"
}
trap 'report_error "$LINENO" "$?" "$BASH_COMMAND"' ERR
trap cleanup EXIT

systemctl --quiet is-active apache2.service mariadb.service postfix.service
systemctl --quiet is-enabled apache2.service mariadb.service postfix.service
apache2ctl -t
apache2ctl -M 2>/dev/null | grep -F ' rewrite_module ' >/dev/null
apache2ctl -M 2>/dev/null | grep -F ' ssl_module ' >/dev/null

curl --insecure --fail --silent --show-error https://localhost/ >"$page"
grep -Eqi 'e107|Welcome' "$page"

curl --insecure --fail --silent --show-error \
    --cookie "$cookie" --cookie-jar "$cookie" \
    https://localhost/ \
    --data-urlencode 'username=admin' \
    --data-urlencode "userpass=$app_password" \
    --data-urlencode 'userlogin=Login' >"$page"
grep -Eqi 'logout|admin area|administrator' "$page"
test -s "$cookie"

test "$(mariadb --batch --skip-column-names e107 --execute \
    "SELECT COUNT(*) FROM e107_user WHERE user_loginname='admin' AND user_admin=1")" = 1
password_hash=$(mariadb --batch --skip-column-names e107 --execute \
    "SELECT user_password FROM e107_user WHERE user_loginname='admin'")
[[ $password_hash == '$2y$'* ]]
test "$(mariadb --batch --skip-column-names e107 --execute 'SHOW TABLES' | wc -l)" -ge 30

test ! -e /var/www/e107/install.php
test "$(stat -c '%a' /var/www/e107/e107_config.php)" = 640
runuser -u www-data -- /usr/bin/php /var/www/e107/cron.php >/dev/null

dpkg-query -W php8.4 php8.4-cli php8.4-curl php8.4-gd php8.4-mbstring \
    php8.4-xml mariadb-server webmin-apache webmin-mysql >/dev/null
curl --insecure --fail --silent --show-error --head \
    https://127.0.0.1:12321/ >/dev/null
ss -ltn | grep -Eq '127\.0\.0\.1:25[[:space:]]'

installed_version=$(sed -n \
    's/^$e107info\['"'"'e107_version'"'"'\][[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
    /var/www/e107/e107_admin/ver.php | head -n1)
test "$installed_version" = 2.3.11

latest_tag=$(curl --fail --silent --show-error \
    https://api.github.com/repos/e107inc/e107/releases/latest |
    sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' | head -n1)
test -n "$latest_tag"

grep -Rqs '^Suites: trixie' /etc/apt/sources.list.d
! grep -Rqi bookworm /etc/apt/sources.list.d

cat >"$result" <<EOF
package_source=Debian 13 Trixie packages plus official e107 GitHub release archive
installed_version=e107 $installed_version; PHP $(php -r 'echo PHP_VERSION;')
runtime_checks=normal init; Apache TLS; administrator web login after firstboot; bcrypt password storage; MariaDB schema; e107 cron; Webmin and local Postfix
updater_command=review and apply an official e107 full or upgrade release following https://e107.org/docs/upgrade
updater_result=official latest release endpoint returned $latest_tag
updater_channel=official e107 GitHub releases
integrity_evidence=build pins e107 2.3.11 archive SHA-256 4e60eec29a061ed295a88ce67fcff05b42cc0a3a55b5a8fa84b65476f3e944bc; Debian package metadata is signed; no Bookworm source remained
EOF
