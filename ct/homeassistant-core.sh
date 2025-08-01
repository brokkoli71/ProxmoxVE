#!/usr/bin/env bash
 source <(curl -fsSL https://raw.githubusercontent.com/brokkoli71/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: tteck (tteckster) | Co-Author: MickLesk (CanbiZ)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://www.home-assistant.io/

APP="Home Assistant-Core"
var_tags="${var_tags:-automation;smarthome}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-10}"
var_os="${var_os:-ubuntu}"
var_version="${var_version:-24.10}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  if ! lsb_release -d | grep -q "Ubuntu 24.10"; then
    msg_error "Wrong OS detected. This script only supports Ubuntu 24.10."
    msg_error "Read Guide: https://github.com/community-scripts/ProxmoxVE/discussions/1549"
    exit 1
  fi
  check_container_storage
  check_container_resources
  if [[ ! -d /srv/homeassistant ]]; then
    msg_error "No ${APP} Installation Found!"
    exit 1
  fi
  setup_uv
  IP=$(hostname -I | awk '{print $1}')
  UPD=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "UPDATE" --radiolist --cancel-button Exit-Script "Spacebar = Select" 11 58 4 \
    "1" "Update Core" ON \
    "2" "Install HACS" OFF \
    "3" "Install FileBrowser" OFF \
    3>&1 1>&2 2>&3)

  if [ "$UPD" == "1" ]; then
    if (whiptail --backtitle "Proxmox VE Helper Scripts" --defaultno --title "SELECT BRANCH" --yesno "Use Beta Branch?" 10 58); then
      clear
      header_info
      echo -e "${GN}Updating to Beta Version${CL}"
      BR="--pre"
    else
      clear
      header_info
      echo -e "${GN}Updating to Stable Version${CL}"
      BR=""
    fi

    msg_info "Stopping Home Assistant"
    systemctl stop homeassistant
    msg_ok "Stopped Home Assistant"

    if [[ -d /srv/homeassistant/bin ]]; then
      msg_info "Migrating to .venv-based structure"
      $STD source /srv/homeassistant/bin/activate
      PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
      $STD deactivate
      mv /srv/homeassistant "/srv/homeassistant_backup_$PY_VER"
      mkdir -p /srv/homeassistant
      cd /srv/homeassistant

      $STD uv python install 3.13
      UV_PYTHON=$(uv python list | awk '/3\.13\.[0-9]+.*\/root\/.local/ {print $2; exit}')
      if [[ -z "$UV_PYTHON" ]]; then
        msg_error "No local Python 3.13 found via uv"
        exit 1
      fi

      $STD uv venv .venv --python "$UV_PYTHON"
      $STD source .venv/bin/activate
      $STD uv pip install homeassistant mysqlclient psycopg2-binary isal webrtcvad wheel
      mkdir -p /root/.homeassistant
      msg_ok "Migration complete"
    else
      source /srv/homeassistant/.venv/bin/activate
    fi

    msg_info "Updating Home Assistant"
    $STD uv pip install $BR --upgrade homeassistant
    msg_ok "Updated Home Assistant"

    msg_info "Starting Home Assistant"
    if [[ -f /etc/systemd/system/homeassistant.service ]] && grep -q "/srv/homeassistant/bin/python3" /etc/systemd/system/homeassistant.service; then
      sed -i 's|ExecStart=/srv/homeassistant/bin/python3|ExecStart=/srv/homeassistant/.venv/bin/python3|' /etc/systemd/system/homeassistant.service
      sed -i 's|PATH=/srv/homeassistant/bin|PATH=/srv/homeassistant/.venv/bin|' /etc/systemd/system/homeassistant.service
      $STD systemctl daemon-reload
    fi

    systemctl start homeassistant
    sleep 5
    msg_ok "Started Home Assistant"
    msg_ok "Update Successful"
    echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8123${CL}"
    exit
  fi

  if [ "$UPD" == "2" ]; then
    msg_info "Installing Home Assistant Community Store (HACS)"
    $STD apt update
    cd /root/.homeassistant
    $STD bash <(curl -fsSL https://get.hacs.xyz)
    msg_ok "Installed Home Assistant Community Store (HACS)"
    echo -e "\n Reboot Home Assistant and clear browser cache then Add HACS integration.\n"
    exit
  fi

  if [ "$UPD" == "3" ]; then
    set +Eeuo pipefail
    read -r -p "${TAB3}Would you like to use No Authentication? <y/N> " prompt
    msg_info "Installing FileBrowser"
    RELEASE=$(curl -fsSL https://api.github.com/repos/filebrowser/filebrowser/releases/latest | grep -o '"tag_name": ".*"' | sed 's/"//g' | sed 's/tag_name: //g')
    $STD curl -fsSL https://github.com/filebrowser/filebrowser/releases/download/$RELEASE/linux-amd64-filebrowser.tar.gz | tar -xzv -C /usr/local/bin

    if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
      $STD filebrowser config init -a '0.0.0.0'
      $STD filebrowser config set -a '0.0.0.0'
      $STD filebrowser config set --auth.method=noauth
      $STD filebrowser users add ID 1 --perm.admin
    else
      $STD filebrowser config init -a '0.0.0.0'
      $STD filebrowser config set -a '0.0.0.0'
      $STD filebrowser users add admin helper-scripts.com --perm.admin
    fi
    msg_ok "Installed FileBrowser"

    msg_info "Creating Service"
    cat <<EOF >/etc/systemd/system/filebrowser.service
[Unit]
Description=Filebrowser
After=network-online.target

[Service]
User=root
WorkingDirectory=/root/
ExecStart=/usr/local/bin/filebrowser -r /root/.homeassistant

[Install]
WantedBy=default.target
EOF

    systemctl enable --now -q filebrowser.service
    msg_ok "Created Service"

    msg_ok "Completed Successfully!\n"
    echo -e "FileBrowser should be reachable by going to the following URL.
         ${BL}http://$IP:8080${CL}   admin|helper-scripts.com\n"
    exit
  fi
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8123${CL}"
