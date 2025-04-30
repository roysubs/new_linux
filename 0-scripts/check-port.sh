PORT=$1   # Replace with the port you want to check
echo "ss -tuln | grep -q \":$PORT\\b\""
if ss -tuln | grep -q ":$PORT\b"; then
  echo "Port $PORT is in use."
else
  echo "Port $PORT is free."
fi
# Explanation:
# ss: Socket statistics utility
# -t: Show TCP sockets
# -u: Show UDP sockets
# -l: Show listening sockets
# -n: Do not resolve service names (faster)
# grep -q ":$PORT\b": Search quietly (-q) for the exact port number preceded by a colon and followed by a word boundary (\b)
# If grep finds a match (exit status 0), the port is in use. Otherwise (exit status 1), it's free.
echo

echo "netstat -tuln | grep -q \":$PORT\\b\""
if netstat -tuln | grep -q ":$PORT\b"; then
  echo "Port $PORT is in use."
else
  echo "Port $PORT is free."
fi
# Explanation:
# netstat: Network statistics
# -t: Show TCP sockets
# -u: Show UDP sockets
# -l: Show listening sockets
# -n: Do not resolve service names (faster)
# grep -q ":$PORT\b": Search quietly for the exact port number followed by a word boundary.
echo

echo "if sudo lsof -i :$PORT > /dev/null"
if sudo lsof -i :$PORT > /dev/null; then
  echo "Port $PORT is in use."
else
  echo "Port $PORT is free."
fi

# Explanation:
# lsof: Lists open files
# -i :$PORT: Filters for network files/sockets related to the specified port number.
# sudo: May be needed to see processes owned by other users (especially root).
# > /dev/null: Redirects standard output to null, so you don't see lsof's output.
# If lsof finds anything (exit status 0), the port is in use. Otherwise (exit status 1), it's free.
# Note: If you don't have sudo or don't want to use it, omit it, but the check might not be complete.
