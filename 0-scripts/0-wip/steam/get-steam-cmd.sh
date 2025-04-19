#!/bin/bash

STEAMCMD=~/steamcmd/steamcmd.sh
SCRIPTFILE=steamcmd_input.txt

# Step 1: Get owned licenses
cat <<EOF > $SCRIPTFILE
login
licenses_print
quit
EOF

OWNED=$( $STEAMCMD +runscript $SCRIPTFILE | grep -Eo '^\s*[0-9]{3,}' | sort -n | uniq )

# Step 2: Query app_status for each
for appid in $OWNED; do
    echo "===== $appid ====="
    echo -e "login\napp_status $appid\nquit" > $SCRIPTFILE
    $STEAMCMD +runscript $SCRIPTFILE | tee -a app_status_output.txt
done

