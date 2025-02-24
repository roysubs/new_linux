sudo apt install -y openssh-server
sudo apt install -y git vim neovim htop btop tmux jq yq ncdu
sudo apt install -y net-tools   # ifconfig and the below:
# arp, ifconfig, netstat, rarp, nameif, route, iptunnel, ipmaddr. Specific hardware: plipconfig, slattach, mii-tool
sudo apt install -y bat         # Provides batcat
sudo apt install -y iftop iotop
sudo apt install -y sysstat
# - sar: collects and reports system activity information
# - iostat: reports CPU utilization and disk I/O statistics
# - tapestat: reports statistics for tapes connected to the system
# - mpstat: reports global and per-processor statistics
# - pidstat: reports statistics for Linux tasks (processes)
# - sadf: displays data collected by sar in various formats
# - cifsiostat: reports I/O statistics for CIFS filesystems

# Parsing tools
# Miller (mlr), works like awk, sed, and cut but for JSON, CSV, and more.
#    mlr --json filter '$field == "value"' file.json
#    mlr --csv cut -f field1,field2 input.csv
# dasel, query and update JSON, YAML, TOML, and XML files.
#    curl -sSL https://github.com/TomWright/dasel/releases/latest/download/dasel_linux_amd64 -o /usr/local/bin/dasel
#    chmod +x /usr/local/bin/dasel
#    dasel get -p yaml -f file.yaml '.fieldName'
#    dasel put string -p json -f file.json '.newField' 'newValue'
# csvkit, tools for working with CSV files.
#    sudo apt install python3-csvkit
#    csvcut -c column_name file.csv
#    csvsql --query "SELECT * FROM file WHERE column='value'" file.csv
# xsv, fast CSV manipulation tool, filter, search, and join CSV files.
#    cargo install xsv
#    xsv select column file.csv
#    xsv sort --reverse column file.csv
# xmllint, parse and validate XML.
#    sudo apt install libxml2-utils
#    xmllint --xpath '//element' file.xml
#    xmllint --format file.xml
# xmlstarlet, Query and manipulate XML.
#    xmlstarlet sel -t -v "//element" file.xml
# LogParser, Analyze structured log files, query logs using SQL, works with IIS, text logs, and CSV.
#    LogParser "SELECT TOP 10 * FROM file.log"
# GoAccess, Real-time web log analyzer.
#    goaccess access.log -o report.html
# ini-cli, Manipulate INI files from the command line.
#    pip install ini-cli
#    ini get file.ini section.key
#    ini set file.ini section.key newValue
