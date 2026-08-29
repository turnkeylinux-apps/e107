#!/bin/bash
set -Eeuo pipefail
umask 077

result=${TKL_TEST_RESULT:?TKL_TEST_RESULT is required}
app_password=${TKL_TEST_APP_PASS:?TKL_TEST_APP_PASS is required}
cookie=/tmp/tkl-e107-cookie.$$
page=/tmp/tkl-e107-page.$$
content_title='TurnKey v19 acceptance article'
content_body='TurnKey e107 content create and read verified'
admin_create_url='https://localhost/e107_admin/newspost.php?mode=main&action=create'

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

curl --insecure --location --fail --silent --show-error \
    --cookie "$cookie" --cookie-jar "$cookie" \
    https://localhost/ \
    --data-urlencode 'username=admin' \
    --data-urlencode "userpass=$app_password" \
    --data-urlencode 'userlogin=Login' >"$page"
grep -Eqi 'logout|admin area|administrator' "$page"
test -s "$cookie"

curl --insecure --location --fail --silent --show-error \
    --cookie "$cookie" --cookie-jar "$cookie" \
    "$admin_create_url" >"$page"
csrf_token=$(sed -n \
    's/.*<meta name="e-token" content="\([^"]*\)".*/\1/p' \
    "$page" | head -n1)
test -n "$csrf_token"

curl --insecure --location --fail --silent --show-error \
    --cookie "$cookie" --cookie-jar "$cookie" \
    "$admin_create_url" \
    --data-urlencode "e-token=$csrf_token" \
    --data-urlencode 'news_category=1' \
    --data-urlencode "news_title=$content_title" \
    --data-urlencode 'news_summary=TurnKey v19 acceptance summary' \
    --data-urlencode "news_body=$content_body" \
    --data-urlencode 'news_extended=' \
    --data-urlencode 'news_sef=turnkey-v19-acceptance-article' \
    --data-urlencode 'news_meta_title=' \
    --data-urlencode 'news_meta_keywords=' \
    --data-urlencode 'news_meta_description=' \
    --data-urlencode 'news_thumbnail=' \
    --data-urlencode 'news_template=default' \
    --data-urlencode 'news_render_type[]=0' \
    --data-urlencode 'news_allow_comments=0' \
    --data-urlencode 'news_start=' \
    --data-urlencode 'news_end=' \
    --data-urlencode 'news_author=1#Administrator' \
    --data-urlencode 'news_class=0' \
    --data-urlencode 'news_sticky=0' \
    --data-urlencode 'etrigger_submit=create' \
    --data-urlencode '__after_submit_action=list' \
    --data-urlencode 'submit_value=0' >"$page"

content_id=$(mariadb --batch --skip-column-names e107 --execute \
    "SELECT news_id FROM e107_news WHERE news_title='$content_title' ORDER BY news_id DESC LIMIT 1")
test -n "$content_id"
test "$(mariadb --batch --skip-column-names e107 --execute \
    "SELECT news_body FROM e107_news WHERE news_id=$content_id")" = "$content_body"
test "$(mariadb --batch --skip-column-names e107 --execute \
    "SELECT CONCAT(news_author, ':', news_class) FROM e107_news WHERE news_id=$content_id")" = '1:0'

curl --insecure --fail --silent --show-error \
    "https://localhost/news.php?extend.$content_id" >"$page"
grep -Fq "$content_title" "$page"
grep -Fq "$content_body" "$page"

test "$(mariadb --batch --skip-column-names e107 --execute \
    "SELECT COUNT(*) FROM e107_user WHERE user_loginname='admin' AND user_admin=1")" = 1
password_hash=$(mariadb --batch --skip-column-names e107 --execute \
    "SELECT user_password FROM e107_user WHERE user_loginname='admin'")
[[ $password_hash == '$2y$'* ]]
test "$(mariadb --batch --skip-column-names e107 --execute 'SHOW TABLES' | wc -l)" -ge 30

test ! -e /var/www/e107/install.php
test "$(stat -c '%a' /var/www/e107/e107_config.php)" = 640
runuser -u www-data -- /usr/bin/php /var/www/e107/cron.php >/dev/null

dpkg-query -W php-cli php-curl php-gd php-mbstring php-xml mariadb-server \
    webmin-apache webmin-mysql >/dev/null
curl --insecure --fail --silent --show-error --head \
    https://127.0.0.1:12321/ >/dev/null
ss -ltn | grep -Eq '127\.0\.0\.1:25[[:space:]]'

installed_version=$(sed -n \
    's/^$e107info\['"'"'e107_version'"'"'\][[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
    /var/www/e107/e107_admin/ver.php | head -n1)
test "$installed_version" = 2.3.11

curl --fail --silent --show-error \
    https://api.github.com/repos/e107inc/e107/releases/latest >"$page"
latest_tag=$(sed -n \
    's/.*"tag_name": "\([^"]*\)".*/\1/p' "$page" | head -n1)
test -n "$latest_tag"
upgrade_asset="e107_v2.x_to_${latest_tag#v}_upgrade.tar.gz"
grep -Fq "\"name\": \"$upgrade_asset\"" "$page"
upgrade_digest=$(php -r '
    $release = json_decode(file_get_contents($argv[1]), true, 512, JSON_THROW_ON_ERROR);
    foreach ($release["assets"] as $asset) {
        if ($asset["name"] === $argv[2]) {
            echo $asset["digest"] ?? "";
            exit;
        }
    }
' "$page" "$upgrade_asset")
[[ $upgrade_digest =~ ^sha256:[[:xdigit:]]{64}$ ]]

grep -Rqs '^Suites: trixie' /etc/apt/sources.list.d
! grep -Rqi bookworm /etc/apt/sources.list.d

cat >"$result" <<EOF
package_source=Debian 13 Trixie packages plus official e107 GitHub release archive
installed_version=e107 $installed_version; PHP $(php -r 'echo PHP_VERSION;')
runtime_checks=normal init; Apache TLS; administrator web login after firstboot; authenticated news create and public read; MariaDB content persistence; bcrypt password storage; e107 cron; Webmin and local Postfix
updater_command=back up the appliance, review the current release notes, and apply $upgrade_asset from the official e107 release
updater_result=official latest release endpoint returned $latest_tag and published $upgrade_asset with $upgrade_digest
updater_channel=official e107 GitHub releases
integrity_evidence=build pins e107 2.3.11 archive SHA-256 4e60eec29a061ed295a88ce67fcff05b42cc0a3a55b5a8fa84b65476f3e944bc; official updater asset publishes $upgrade_digest; Debian package metadata is signed; no Bookworm source remained
EOF
