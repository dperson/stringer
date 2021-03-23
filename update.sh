#!/usr/bin/env bash
# podman run --rm -it -v $HOME/projects/stringer:/pass:z fedora bash
# dnf install -y rubygem-bundler
# bundle lock --update
# ... fix bundle / ruby and run again
# podman system prune -af --volumes
db_update() {
    APP=$(grep 'git\.heroku' .git/config | sed 's|.*/||; s|\.git||')
    DB=$(heroku pg:info | awk '/^===/ {print $NF}')
    echo "$DB" | wc -w | egrep -q '\<1\>' || exit
    heroku addons:create heroku-postgresql:hobby-dev
    NEWDB=$(heroku pg:info | awk '/^===/ && !/'"$DB"'/ {print $NF}')
    [[ "$NEWDB" ]] || { echo "ERROR: Creating migration DB failed!"; exit 1; }
    heroku pg:wait
    heroku maintenance:on
    heroku pg:copy $DB $NEWDB --app $APP --confirm yes $APP
    heroku pg:promote $NEWDB
    heroku maintenance:off
    heroku addons:destroy $DB --confirm yes $APP
}
db_flush() {
    APP=$(grep 'git\.heroku' .git/config | sed 's|.*/||; s|\.git||')
    DB=$(heroku pg:info | awk '/^===/ {print $NF}')
    echo "$DB" | wc -w | egrep -q '\<1\>' || exit
    heroku pg:wait
    heroku maintenance:on
    heroku pg:backups capture
    heroku pg:backups restore $DB --confirm yes $APP
    heroku maintenance:off
}
heroku_inst() {
    echo -n "Installing latest heroku cli..."
    URL="https://cli-assets.heroku.com/heroku-linux-x64.tar.gz"
    \rm -rf ~/.local/bin/heroku ~/.local/share/heroku
    [[ -d ~/.local/share ]] || mkdir -p ~/.local/share
    tar -C ~/.local/share -xzf <(curl -LSs "$URL")
    [[ -d ~/.local/bin ]] || mkdir -p ~/.local/bin
    \ln -s ../share/heroku/bin/heroku ~/.local/bin/
    echo " done"
}

[[ -x $(which heroku 2>/dev/null) ]] || heroku_inst

cd $(dirname $0)
grep -q heroku .git/config ||
            git remote add heroku git@heroku.com:thawing-ravine-5363.git
grep -q upstream .git/config ||
            git remote add upstream https://github.com/swanson/stringer.git

git checkout tweak
git pull origin tweak:tweak
[[ "$1" == "--db" ]] && db_update
[[ "$1" == "--flush" ]] && db_flush
[[ "$1" == "--heroku" ]] && { heroku_inst; exit 0; }

set -x
#heroku run rake 'cleanup_old_stories[90]'
heroku pg:info

git checkout master
git pull upstream master:master || exit
git checkout tweak

git rebase master || exit
git push --all -ff origin || exit
git push -ff heroku tweak:master || exit
heroku run rake db:migrate
heroku restart