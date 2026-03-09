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

MONITOR_DIR="/etc/ssh/.ssh-monitoring"
MANAGER_FILE="/etc/ssh/ssh_manager.sh"
CRON_FILE="/etc/ssh/ssh_cron.SH"
BANNER_FILE="/etc/ssh/banner.txt"

########################################
# LOG FUNCTIONS
########################################

info(){ echo -e "${BLUE}ℹ️  $1${RESET}"; }
success(){ echo -e "${GREEN}✅ $1${RESET}"; }
warn(){ echo -e "${YELLOW}⚠️  $1${RESET}"; }
fail(){ echo -e "${RED}❌ $1${RESET}"; exit 1; }

########################################
# LOADER
########################################

run_with_loader(){

msg=$1
shift

echo -ne "⏳ $msg"

"$@" > /dev/null 2>&1 &
pid=$!

dots=""

while kill -0 $pid 2>/dev/null; do

dots="$dots."

[ ${#dots} -gt 3 ] && dots="."

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

echo -e "${RED}"
echo "======================================="
echo "   SSH MONITORING UNINSTALLER"
echo "======================================="
echo -e "${RESET}"

[ "$EUID" -ne 0 ] && fail "Run this script with root or sudo"

success "Root permission confirmed"

########################################
# CONFIRMATION
########################################

echo
warn "This will completely remove SSH Monitoring."
warn "All monitoring logs and hidden folders will be deleted."

echo
select CONFIRM in "Yes, uninstall everything" "Cancel"; do

case $REPLY in

1) break ;;

2) fail "Uninstall cancelled" ;;

*) echo "Invalid option" ;;

esac

done

########################################
# REMOVE CRON
########################################

run_with_loader "Removing cron job" bash -c \
"(crontab -l 2>/dev/null | grep -v '$CRON_FILE') | crontab -"

########################################
# REMOVE FORCECOMMAND
########################################

if grep -q "^ForceCommand $MANAGER_FILE" "$SSH_CONFIG"; then

run_with_loader "Removing ForceCommand from sshd_config" \
sed -i "\|ForceCommand $MANAGER_FILE|d" "$SSH_CONFIG"

success "ForceCommand removed"

else

info "No ForceCommand entry found"

fi

########################################
# REMOVE BANNER
########################################

if grep -q "^Banner $BANNER_FILE" "$SSH_CONFIG"; then

run_with_loader "Removing SSH banner configuration" \
sed -i "\|Banner $BANNER_FILE|d" "$SSH_CONFIG"

success "Banner removed"

else

info "No banner configuration found"

fi

########################################
# DELETE FILES
########################################

run_with_loader "Deleting ssh_manager" rm -f "$MANAGER_FILE"

run_with_loader "Deleting cron script" rm -f "$CRON_FILE"

run_with_loader "Deleting banner file" rm -f "$BANNER_FILE"

########################################
# DELETE SECRET FOLDER
########################################

if [ -d "$MONITOR_DIR" ]; then

run_with_loader "Deleting hidden monitoring folder" rm -rf "$MONITOR_DIR"

success "Hidden monitoring folder removed"

else

info "Monitoring folder not found"

fi

########################################
# RESTART SSH
########################################

run_with_loader "Restarting SSH service" systemctl restart sshd || service ssh restart

########################################
# FINISH
########################################

echo
echo -e "${GREEN}"
echo "🎉 SSH Monitoring successfully removed!"
echo
echo "All files, cron jobs, and hidden folders were deleted."
echo -e "${RESET}"
