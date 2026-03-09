#!/bin/bash

set -e

########################################
# COLORS
########################################

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

########################################
# PATHS
########################################

SSH_CONFIG="/etc/ssh/sshd_config"
SSH_BACKUP="/etc/ssh/sshd_config.backup.$(date +%s)"

MONITOR_DIR="/etc/ssh/.ssh-monitoring"
MANAGER_FILE="/etc/ssh/ssh_manager.sh"
CRON_FILE="/etc/ssh/ssh_cron.SH"
BANNER_FILE="/etc/ssh/banner.txt"

REPO="Sulaymon-Dev20/SSH-MONITORING"

########################################
# LOG FUNCTIONS
########################################

info() { echo -e "${BLUE}ℹ️  $1${RESET}"; }
success() { echo -e "${GREEN}✅ $1${RESET}"; }
warn() { echo -e "${YELLOW}⚠️  $1${RESET}"; }
fail() { echo -e "${RED}❌ $1${RESET}"; exit 1; }

########################################
# LOADER
########################################

run_with_loader() {

msg=$1
shift

echo -ne "⏳ $msg"

"$@" > /dev/null 2>&1 &
pid=$!

dots=""

while kill -0 $pid 2>/dev/null; do

dots="$dots."

if [ ${#dots} -gt 3 ]; then
dots="."
fi

echo -ne "\r⏳ $msg$dots "
sleep 0.5

done

wait $pid
status=$?

if [ $status -eq 0 ]; then
echo -e "\r${GREEN}✅ $msg completed${RESET}"
else
echo -e "\r${RED}❌ $msg failed${RESET}"
exit 1
fi

}

########################################
# ROOT CHECK
########################################

clear
echo -e "${BLUE}"
echo "======================================="
echo "   SSH MONITORING INSTALLER"
echo "======================================="
echo -e "${RESET}"

[ "$EUID" -ne 0 ] && fail "Run this installer as root or sudo"

success "Root permission confirmed"

########################################
# FETCH VERSIONS
########################################

info "Fetching available versions..."

VERSIONS=$(curl -s https://api.github.com/repos/$REPO/releases \
| grep tag_name \
| cut -d '"' -f4 \
| head -n 4)

OPTIONS=("Latest")

while read -r v; do
OPTIONS+=("$v")
done <<< "$VERSIONS"

echo
echo "Select version to install:"
select VERSION in "${OPTIONS[@]}"; do
[ -n "$VERSION" ] && break
done

if [ "$VERSION" == "Latest" ]; then
BASE_URL="https://github.com/$REPO/releases/latest/download"
else
BASE_URL="https://github.com/$REPO/releases/download/$VERSION"
fi

success "Selected version: $VERSION"

########################################
# BACKUP SSH CONFIG
########################################

run_with_loader "Creating sshd_config backup" cp "$SSH_CONFIG" "$SSH_BACKUP"

success "Backup created at $SSH_BACKUP"

########################################
# FORCECOMMAND CHECK
########################################

CURRENT_FORCE=$(grep -i "^ForceCommand" "$SSH_CONFIG" || true)

if [ -n "$CURRENT_FORCE" ]; then

warn "ForceCommand already exists:"
echo "$CURRENT_FORCE"
echo

select ACTION in "Overwrite existing ForceCommand" "Remove existing ForceCommand" "Cancel installation"; do

case $REPLY in

1)
sed -i '/^ForceCommand/d' "$SSH_CONFIG"
success "Existing ForceCommand removed"
break
;;

2)
sed -i '/^ForceCommand/d' "$SSH_CONFIG"
success "ForceCommand cleared"
break
;;

3)
fail "Installation cancelled"
;;

*)
echo "Invalid option"
;;

esac
done

else

success "ForceCommand is empty"

fi

########################################
# CREATE MONITOR DIRECTORY
########################################

run_with_loader "Creating monitoring directory" mkdir -p "$MONITOR_DIR"

chmod 733 "$MONITOR_DIR"

success "Monitoring directory ready"

########################################
# DOWNLOAD FILES
########################################

run_with_loader "Downloading ssh_monitoring" \
curl -L "$BASE_URL/ssh_monitoring.SH" -o "$MANAGER_FILE"

chmod +x "$MANAGER_FILE"

run_with_loader "Downloading ssh_cron" \
curl -L "$BASE_URL/ssh_cron.SH" -o "$CRON_FILE"

chmod +x "$CRON_FILE"

run_with_loader "Downloading banner file" \
curl -L "$BASE_URL/banner.txt" -o "$BANNER_FILE"

chmod 644 "$BANNER_FILE"

########################################
# CRON JOB
########################################

run_with_loader "Installing cron job" bash -c \
"(crontab -l 2>/dev/null | grep -v '$CRON_FILE'; echo '*/30 * * * * $CRON_FILE') | crontab -"

success "Cron installed (every 30 minutes)"

########################################
# ADD SSH SETTINGS
########################################

run_with_loader "Adding ForceCommand" bash -c \
"echo 'ForceCommand $MANAGER_FILE' >> $SSH_CONFIG"

if grep -q "^Banner" "$SSH_CONFIG"; then
sed -i "s|^Banner.*|Banner $BANNER_FILE|" "$SSH_CONFIG"
else
echo "Banner $BANNER_FILE" >> "$SSH_CONFIG"
fi

success "SSH banner configured"

########################################
# RESTART SSH
########################################

run_with_loader "Restarting SSH service" systemctl restart sshd || service ssh restart

########################################
# FINISH
########################################

echo
echo -e "${GREEN}"
echo "🎉 Installation completed successfully!"
echo
echo "Directory : $MONITOR_DIR"
echo "Version   : $VERSION"
echo "Cron      : every 30 minutes"
echo "Backup    : $SSH_BACKUP"
echo -e "${RESET}"
